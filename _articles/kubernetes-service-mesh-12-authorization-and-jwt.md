---
layout: post
title: "Authorization Policies and JWT at the Istio Gateway"
series: "Kubernetes Advanced: Service Mesh"
series_url: /kubernetes-service-mesh-series/
part: 12
date: 2026-11-09
author: Quan Huynh
subtitle: "Deny everything, then allow only the calls Book Store makes by workload identity, and protect an admin API at the gateway with signed tokens."
tags: [kubernetes, istio, service-mesh, authorization, jwt]
image: /assets/images/posts/kubernetes-service-mesh-12-authorization-and-jwt/cover.svg
---

Chapter 11 made every connection inside `bookstore` mutually authenticated. Each sidecar now
knows exactly who is calling: `spiffe://cluster.local/ns/bookstore/sa/bookstore-productpage`,
not just an IP. But knowing who is calling isn't the same as deciding whether they may. Any
workload with a sidecar in any namespace can still call `ratings`, and nothing stops a
compromised `details` Pod from calling `reviews`.

This chapter adds that decision. An `AuthorizationPolicy` says which identities may call which
workload, with which methods and paths. The usual pattern is *default deny*: block everything,
then allow exactly the calls the app makes. The second half of the chapter protects something
humans use: an admin API for changing ratings, exposed through the ingress gateway and open only
to requests that carry a valid signed token (a JWT) with the right role.

By the end of this chapter you will:

- Lock `bookstore` down with a default-deny policy and allow Book Store's four calls by identity.
- Read a denial in the access log (`rbac_access_denied_matched_policy`) and find which policy
  caused it.
- Explain the order in which Istio evaluates `CUSTOM`, `DENY`, and `ALLOW` policies.
- Validate JWTs at the gateway with a `RequestAuthentication`, and require a role claim with a
  `DENY` policy.

> **Code for this chapter.** The files are in
> [_resource/kubernetes-service-mesh/12-authorization](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/kubernetes-service-mesh/12-authorization),
> and the token script is `scripts/make-jwt.sh`. I tested them with Kind v0.33.0 (Kubernetes
> v1.37.0) and Istio 1.32.0 on macOS with Docker Desktop, and the command output in this chapter
> comes from those runs.

## Starting Point

Run every command from `_resource/kubernetes-service-mesh`:

```sh
export PATH="$PWD/bin:$PATH"
```

The chapter needs chapter 11's end state: Book Store at `http://bookstore.local:8080`, with
`STRICT` mTLS in `bookstore`. Authorization by identity depends on mTLS: without a client
certificate, there is no identity to check. To build the state from scratch:

```sh
./scripts/bootstrap.sh 12
```

## How Istio Evaluates a Request

An `AuthorizationPolicy` is enforced by the sidecar (or gateway) of the workload it selects, for
every request that workload receives. Each policy has an `action`, and the sidecar evaluates them
in a fixed order:

![How a request is evaluated: first CUSTOM policies, then DENY policies, where any match means the request is denied; then ALLOW policies, where a match means allowed; if ALLOW policies exist for the workload but none matches, the request is denied; if no ALLOW policy exists at all, the request is allowed](/assets/images/posts/kubernetes-service-mesh-12-authorization-and-jwt/policy-evaluation.svg)

1. `CUSTOM` policies, which ask an external authorization service. (Not used in this series.)
2. `DENY` policies. If any matches, the request is denied.
3. `ALLOW` policies. If any matches, the request is allowed.
4. If the workload has at least one `ALLOW` policy and none matched, the request is denied. If it
   has no `ALLOW` policy at all, the request is allowed.

Rule 4 is the one that surprises people: adding your first `ALLOW` policy to a workload silently
denies everything that policy doesn't mention. It's also how default deny works.

## Default Deny

`12-authorization/deny-all.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
  namespace: bookstore
spec: {}
```

An empty `spec` means: no `selector`, so it applies to every workload in `bookstore`; the default
action, `ALLOW`; and no rules, so it matches nothing. By rule 4, every workload now has an
`ALLOW` policy that matches nothing, so every request is denied.

```sh
kubectl apply -f 12-authorization/deny-all.yaml
curl -s -w " %{http_code}\n" --resolve bookstore.local:8080:127.0.0.1 http://bookstore.local:8080/productpage
./scripts/count-versions.sh http://bookstore.local:8080 5
```

```text
authorizationpolicy.security.istio.io/allow-nothing created
RBAC: access denied 403
   5 403 reviews-none - fast
```

`RBAC: access denied` is the body Envoy returns for a denied request. (Istio's authorization was
once called RBAC, role-based access control, and the name stuck in Envoy.)

Give the policy a few seconds before you trust the result. `istiod` pushes it to each sidecar
separately, so for a moment some sidecars enforce it and others don't. In my first try, the page
came back `200` with "Error fetching product details": `details` had the policy already and
refused `productpage`, but `productpage` hadn't received it yet and still let the gateway in.

The sidecar that refuses a request logs it. Every request from `count-versions.sh` enters through
`productpage`, which now refuses it, so read that sidecar's last line:

```sh
kubectl -n bookstore logs deploy/productpage-v1 -c istio-proxy --tail=1
```

```text
[2026-11-17T02:08:47.012Z] "GET /api/v1/products/0/reviews HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] - "-" 0 19 0 - "172.21.0.4" "curl/8.7.1" "a55bc040-6e76-48e3-b12e-0b7e90225bc4" "bookstore.local:8080" "-" inbound|9080|| - 10.244.2.16:9080 172.21.0.4:0 outbound_.9080_._.productpage.bookstore.svc.cluster.local default
```

`rbac_access_denied_matched_policy[none]` means "denied, and no policy matched": the rule 4 case.
When a `DENY` policy causes a denial, the brackets name it, as you'll see at the gateway later.

## Allow Exactly What Book Store Does

Book Store makes four kinds of calls. `12-authorization/allow-bookstore.yaml` has one `ALLOW`
policy per workload, each naming the only caller allowed in:

| Workload | Allowed caller (principal) | Methods |
| --- | --- | --- |
| `productpage` | `cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account` | any |
| `details` | `cluster.local/ns/bookstore/sa/bookstore-productpage` | `GET` |
| `reviews` | `cluster.local/ns/bookstore/sa/bookstore-productpage` | `GET` |
| `ratings` | `cluster.local/ns/bookstore/sa/bookstore-reviews` | `GET` |

A *principal* is the identity from chapter 11 without the `spiffe://` prefix. The `ratings`
policy:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: ratings
  namespace: bookstore
spec:
  selector:
    matchLabels:
      app: ratings
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/bookstore/sa/bookstore-reviews
      to:
        - operation:
            methods: ["GET"]
```

- `selector` picks the `ratings` Pods. The policy is enforced by their sidecars.
- `from.source.principals` is who may call. All three `reviews` versions run as
  `bookstore-reviews`, so one principal covers them.
- `to.operation.methods` is what they may do. `reviews` only reads ratings.

Inside one rule, `from` and `to` must both match. Separate rules are alternatives: a request that
matches any one of them is allowed. The `productpage` policy has no `to`, so the gateway may send
it any method and path. Apply all four:

```sh
kubectl apply -f 12-authorization/allow-bookstore.yaml
./scripts/count-versions.sh http://bookstore.local:8080 20
```

```text
authorizationpolicy.security.istio.io/productpage created
authorizationpolicy.security.istio.io/details created
authorizationpolicy.security.istio.io/reviews created
authorizationpolicy.security.istio.io/ratings created
   8 200 reviews-v1 no-stars fast
   7 200 reviews-v2 stars fast
   5 200 reviews-v3 stars fast
```

Book Store works again. (Run it right after the `apply` and the first requests may still get
`403`, for the same propagation reason as before.)

Now check that nothing else gets in. Start a test Pod in `bookstore`. The namespace has
injection on, so the Pod gets a sidecar and a valid mesh identity, just not an allowed one:

```sh
kubectl -n bookstore run tester --image=docker.io/curlimages/curl:8.16.0 \
  --restart=Never --command -- sleep 3600
kubectl -n bookstore wait --for=condition=Ready pod/tester --timeout=90s
kubectl -n bookstore exec tester -c tester -- curl -s -w " %{http_code}\n" http://ratings:9080/ratings/0
kubectl -n bookstore exec tester -c tester -- curl -s -w " %{http_code}\n" http://details:9080/details/0
```

```text
pod/tester created
pod/tester condition met
RBAC: access denied 403
RBAC: access denied 403
```

A Pod in the right namespace, with mTLS, is still refused, because its identity
(`.../sa/default`) isn't on any list. A NetworkPolicy, chapter 1's partial answer, could keep
`tester` out too, but it decides per connection, by Pod labels that it turns into IP addresses.
An `AuthorizationPolicy` checks the identity in the caller's certificate on every request, and
it can limit the method as well, like the `GET` in three of the four policies.

The figure shows what is left: the four kinds of call Book Store makes, and nothing else:

![The allowed call graph after default deny: the ingress gateway may call productpage, productpage may call details and reviews with GET, reviews may call ratings with GET; every other edge, such as the tester Pod calling ratings or details calling reviews, is denied](/assets/images/posts/kubernetes-service-mesh-12-authorization-and-jwt/allowed-graph.svg)

## Break It: A Typo in a Service Account

Someone edits the `ratings` policy and drops one letter from the service account:
`bookstore-review` instead of `bookstore-reviews`.

```sh
kubectl -n bookstore patch authorizationpolicy ratings --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/from/0/source/principals/0","value":"cluster.local/ns/bookstore/sa/bookstore-review"}]'
./scripts/count-versions.sh http://bookstore.local:8080 20
```

```text
authorizationpolicy.security.istio.io/ratings patched
   7 200 reviews-v3 ratings-error fast
   6 200 reviews-v1 no-stars fast
   5 200 reviews-v2 ratings-error fast
   1 200 reviews-v3 stars fast
   1 200 reviews-v2 stars fast
```

Stars disappear across the site. (The two pages with stars were served while the change was still
reaching the `ratings` sidecar.) The pages still return `200`, as in chapter 1's outage, so a
status-code alert sees nothing. `istioctl analyze` doesn't help either:

```sh
istioctl analyze -n bookstore
```

```text
✔ No validation issues found when analyzing namespace: bookstore.
```

The principal is a valid string, and Istio can't know which service accounts *should* exist.

Find it from the `ratings` side:

```sh
kubectl -n bookstore logs deploy/ratings-v1 -c istio-proxy --tail=1
```

```text
[2026-11-17T02:09:24.433Z] "GET /ratings/0 HTTP/1.1" 403 - rbac_access_denied_matched_policy[none] - "-" 0 19 0 - "-" "curl/8.7.1" "7769c6a7-39f2-47a0-b9a1-cee7123e3b76" "ratings:9080" "-" inbound|9080|| - 10.244.1.18:9080 10.244.2.11:44468 outbound_.9080_._.ratings.bookstore.svc.cluster.local default
```

`403` with `[none]`: an `ALLOW` policy exists and nothing matched. The caller's IP,
`10.244.2.11` (the downstream remote address in chapter 5's table), belongs to a `reviews` Pod;
`kubectl -n bookstore get pod -o wide` maps IPs to Pods. Now compare the caller's real identity
with the policies that apply to `ratings`:

```sh
kubectl -n bookstore get pod -l app=reviews -o custom-columns=POD:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName
istioctl x authz check deploy/ratings-v1 -n bookstore
```

```text
POD                           SERVICEACCOUNT
reviews-v1-678d69454f-xz8dc   bookstore-reviews
reviews-v2-5c8db7b6c5-clc8n   bookstore-reviews
reviews-v3-74946666d9-sd2xm   bookstore-reviews
ACTION   AuthorizationPolicy       RULES
ALLOW    allow-nothing.bookstore   1
ALLOW    ratings.bookstore         1
```

All three `reviews` Pods run as `bookstore-reviews`. `istioctl x authz check` lists the policies
that apply to a workload, and two apply to `ratings`. (It counts the empty `allow-nothing` policy
as one rule, a rule with no conditions that can never match.) `allow-nothing` is the default deny
and is meant to match nothing, so the only policy that should let `reviews` in is `ratings`.
`kubectl -n bookstore get authorizationpolicy ratings -o yaml` shows `bookstore-review` in its
principal. Restore the policy from the file:

```sh
kubectl apply -f 12-authorization/allow-bookstore.yaml
```

The lesson for real clusters: a wrong principal fails closed and silently. Test every policy change
with a request from the real caller, and watch for `403`s in the callee's sidecar log or in the
`istio_requests_total{response_code="403"}` metric (chapter 13).

## An Admin API Protected by JWT

The Book Store team wants an admin endpoint to correct ratings by hand. `ratings` already has one:
`POST /ratings/<id>` with a JSON body replaces the ratings stored in that Pod's memory.
`12-authorization/admin-host.yaml` exposes it on a new host, `admin.bookstore.local`, by adding the
host to the `Gateway` and a `VirtualService` that routes `/ratings/` to `ratings`. The `ratings`
policy also has to let the gateway in; `12-authorization/allow-ratings-admin.yaml` replaces it with
two rules:

```yaml
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/bookstore/sa/bookstore-reviews
      to:
        - operation:
            methods: ["GET"]
    - from:
        - source:
            principals:
              - cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/ratings/*"]
```

The first rule is the one from before. The second lets the gateway's identity read and write,
but only under `/ratings/`. Apply both files and send a write through the new host:

```sh
kubectl apply -f 12-authorization/admin-host.yaml -f 12-authorization/allow-ratings-admin.yaml
curl -s -w " %{http_code}\n" --resolve admin.bookstore.local:8080:127.0.0.1 \
  -X POST -H 'Content-Type: application/json' -d '{"Reviewer1":1,"Reviewer2":1}' \
  http://admin.bookstore.local:8080/ratings/0
```

```text
gateway.networking.istio.io/bookstore-gateway configured
virtualservice.networking.istio.io/bookstore-admin created
authorizationpolicy.security.istio.io/ratings configured
{"id":0,"ratings":{"Reviewer1":1,"Reviewer2":1}} 200
```

The write works, and the request carried no credentials at all. Anyone who can reach the gateway
can now rewrite every rating. The mesh identity check can't help here: the caller of `ratings` is
the gateway, and the gateway forwards requests from any client that reaches it. What's needed is
an identity for the *person* sending the request, checked at the gateway.

### Tokens and keys

A *JSON Web Token* (JWT) is a signed JSON document: who the user is (`sub`), who issued the token
(`iss`), when it expires (`exp`), and any extra *claims*, such as a role. An identity provider
(Keycloak, Auth0, Google, and so on) signs tokens with a private key and publishes the matching
public keys as a *JWKS* (JSON Web Key Set). Anyone with the JWKS can verify a token without
contacting the issuer.

`scripts/make-jwt.sh` plays the identity provider. It creates a key pair, the JWKS, and two tokens
signed by the issuer `https://auth.bookstore.local`, using only `openssl` and `python3`:

```sh
./scripts/make-jwt.sh
cut -d. -f2 jwt/admin.jwt | python3 -c 'import base64,sys; s=sys.stdin.read().strip(); print(base64.urlsafe_b64decode(s+"="*(-len(s)%4)).decode())'
```

```text
created admin.jwt (sub=alice, role=admin)
created viewer.jwt (sub=bob, role=viewer)
created requestauthentication.yaml (issuer https://auth.bookstore.local)
{"iss":"https://auth.bookstore.local","sub":"alice","role":"admin","iat":1794881299,"exp":1826417299}
```

A JWT is three base64url parts joined by dots: header, claims, signature. The second command
decodes the middle part of the admin token: issuer, subject `alice`, role `admin`, and `iat`
(issued at) and `exp` (expires) as Unix timestamps, one year apart. Anyone can decode a JWT
this way; the claims are encoded, not encrypted, so never put secrets in them. What can't be
faked is the signature. `jwt/` also holds the private key, `key.pem`, and is in `.gitignore`.

### Validate tokens: RequestAuthentication

`make-jwt.sh` also wrote `jwt/requestauthentication.yaml` from the template
`12-authorization/requestauthentication.yaml.tpl`, with your public key inline:

```yaml
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: bookstore-jwt
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  jwtRules:
    - issuer: "https://auth.bookstore.local"
      jwks: |
        {"keys": [{"kty": "RSA", "alg": "RS256", "use": "sig", "kid": "bookstore-2026", "n": "...", "e": "AQAB"}]}
```

A `RequestAuthentication` tells the gateway how to check tokens from this issuer: the `selector`
picks the ingress gateway Pods, and `jwks` holds the public key. In production you would use
`jwksUri` with the provider's URL instead of an inline key, so key rotation needs no change here.

For each request, a `RequestAuthentication` has three outcomes, and the third is the one people
miss:

- A valid token: the request gets a *request principal*, `<iss>/<sub>`, and its claims are
  available to policies.
- An invalid token (bad signature, expired, wrong issuer): the gateway rejects it with `401`.
- **No token: the request passes**, with no request principal.

So a `RequestAuthentication` alone protects nothing. A policy has to require the token.

### Require a token with the admin role: a DENY policy

`12-authorization/gateway-admin-policy.yaml` is enforced by the gateway and denies two kinds of
request to the admin host:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: admin-requires-jwt
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  action: DENY
  rules:
    - from:
        - source:
            notRequestPrincipals: ["*"]
      to:
        - operation:
            hosts: ["admin.bookstore.local", "admin.bookstore.local:*"]
            ports: ["8080"]
    - to:
        - operation:
            hosts: ["admin.bookstore.local", "admin.bookstore.local:*"]
            ports: ["8080"]
      when:
        - key: request.auth.claims[role]
          notValues: ["admin"]
```

- Rule 0 denies requests with no request principal: `notRequestPrincipals: ["*"]` matches when
  the request principal isn't anything at all, which means no token. (A request with an invalid
  token never gets this far; it was already rejected with `401`.)
- Rule 1 denies requests whose `role` claim isn't `admin`.
- `hosts` lists the name with and without a port, because curl sends
  `Host: admin.bookstore.local:8080` when the URL has a port, as every URL on Kind does here.
- `ports: ["8080"]` limits it to the gateway's HTTP port (the Pod port behind Service port 80). My
  first version left it out, and `kubectl apply` printed this warning: `configured
  AuthorizationPolicy will deny all traffic to TCP ports under its scope due to the use of only HTTP
  attributes in a DENY rule; it is recommended to explicitly specify the port`. TCP traffic has no host,
  token, or claims, so when Istio builds the TCP version of a `DENY` rule that uses only HTTP
  fields, it drops those conditions. The rule then matches, and denies, every TCP connection
  through the gateway. Chapter 4's `PASSTHROUGH` route to payments was such traffic. It's gone
  now, but a policy shouldn't depend on that.

Why `DENY` and not `ALLOW`? The gateway serves the shop too. An `ALLOW` policy on the gateway
would, by rule 4, deny every request it doesn't list, including all of `bookstore.local`. A `DENY`
policy scoped to one host leaves everything else alone.

The figure puts the two objects in order for a request to the admin host. The token check comes
first, then the `DENY` policy, then `ratings`' own `ALLOW` policy from earlier:

![JWT at the gateway: a request to admin.bookstore.local first meets RequestAuthentication, which rejects a bad token with 401 and turns a valid one into a request principal with claims; then the DENY policy rejects requests with no principal or a role other than admin with 403; an admin token passes to ratings, which allows the gateway's identity to GET and POST](/assets/images/posts/kubernetes-service-mesh-12-authorization-and-jwt/jwt-at-gateway.svg)

Apply both, then send four requests to the admin host and one to the shop. The four callers are:
no token, a forged token, the viewer token, and the admin token. The forged token is written out
inline: it claims `sub: mallory` and `role: admin` from the right issuer, but its signature is
just the base64 of the word "signature":

```sh
kubectl apply -f jwt/requestauthentication.yaml -f 12-authorization/gateway-admin-policy.yaml
R="admin.bookstore.local:8080:127.0.0.1"
curl -s -w " %{http_code}\n" --resolve "$R" http://admin.bookstore.local:8080/ratings/0
curl -s -w " %{http_code}\n" --resolve "$R" \
  -H 'Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2F1dGguYm9va3N0b3JlLmxvY2FsIiwic3ViIjoibWFsbG9yeSIsInJvbGUiOiJhZG1pbiJ9.c2lnbmF0dXJl' \
  http://admin.bookstore.local:8080/ratings/0
curl -s -w " %{http_code}\n" --resolve "$R" -H "Authorization: Bearer $(cat jwt/viewer.jwt)" \
  http://admin.bookstore.local:8080/ratings/0
curl -s -w " %{http_code}\n" --resolve "$R" -H "Authorization: Bearer $(cat jwt/admin.jwt)" \
  -X POST -H 'Content-Type: application/json' -d '{"Reviewer1":5,"Reviewer2":4}' \
  http://admin.bookstore.local:8080/ratings/0
curl -s -o /dev/null -w "%{http_code}\n" --resolve bookstore.local:8080:127.0.0.1 http://bookstore.local:8080/productpage
```

```text
requestauthentication.security.istio.io/bookstore-jwt created
authorizationpolicy.security.istio.io/admin-requires-jwt created
RBAC: access denied 403
Jwt verification fails 401
RBAC: access denied 403
{"id":0,"ratings":{"Reviewer1":5,"Reviewer2":4}} 200
200
```

No token: `403`. Forged token: `401`, rejected before any policy runs. Viewer: `403`. Admin: the
write succeeds and puts the ratings back to 5 and 4 stars, the values the anonymous request
overwrote. And the shop at `bookstore.local` still answers `200`.

The gateway's log names each outcome. `cut -c1-200` keeps the first 200 characters of each line,
enough for the status and the reason:

```sh
kubectl -n istio-system logs deploy/istio-ingressgateway --tail=5 | cut -c1-200
```

```text
[2026-11-17T02:21:13.273Z] "GET /ratings/0 HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[istio-system]-policy[admin-requires-jwt]-rule[0]] - "-" 0 19 0 - "172.21.0.4" "curl/8.7.1" "64a312a2-39a
[2026-11-17T02:21:13.292Z] "GET /ratings/0 HTTP/1.1" 401 - jwt_authn_access_denied{Jwt_verification_fails} - "-" 0 22 0 - "172.21.0.4" "curl/8.7.1" "a7581ed9-f09e-9da0-bfab-60994e1ac3e8" "admin.bookst
[2026-11-17T02:21:13.311Z] "GET /ratings/0 HTTP/1.1" 403 - rbac_access_denied_matched_policy[ns[istio-system]-policy[admin-requires-jwt]-rule[1]] - "-" 0 19 0 - "172.21.0.4" "curl/8.7.1" "301f44cb-0a2
[2026-11-17T02:21:13.323Z] "POST /ratings/0 HTTP/1.1" 200 - via_upstream - "-" 29 48 11 11 "172.21.0.4" "curl/8.7.1" "bbc0e3b4-ec87-980d-9319-6484a60c52e0" "admin.bookstore.local:8080" "10.244.1.20:90
[2026-11-17T02:21:13.344Z] "GET /productpage HTTP/1.1" 200 - via_upstream - "-" 0 15072 48 47 "172.21.0.4" "curl/8.7.1" "d8b148eb-a5dd-94c8-ba4e-8cc804785dbf" "bookstore.local:8080" "10.244.2.16:9080"
```

This time the brackets name the policy and the rule: `rule[0]` for the missing token, `rule[1]`
for the wrong role. The `401` comes from a different filter, `jwt_authn`, which checks tokens
before authorization runs.

## Reset Before the Next Chapter

Chapter 13 adds a new service that calls `productpage`, and chapter 14 a second gateway with its
own identity. These policies would block both, so remove the policies, the token check, the admin host, and the test Pod. Keep
`STRICT` mTLS. `--ignore-not-found` is there because `allow-ratings-admin.yaml` and
`allow-bookstore.yaml` both define the `ratings` policy, so the second delete finds it gone.
Reapplying chapter 3's `gateway.yaml` takes `admin.bookstore.local` off the `Gateway`:

```sh
kubectl delete -f 12-authorization/gateway-admin-policy.yaml -f jwt/requestauthentication.yaml
kubectl delete -f 12-authorization/allow-ratings-admin.yaml -f 12-authorization/allow-bookstore.yaml \
  -f 12-authorization/deny-all.yaml --ignore-not-found
kubectl delete virtualservice bookstore-admin -n bookstore
kubectl apply -f 03-gateway-virtualservice/gateway.yaml
kubectl -n bookstore delete pod tester
```

To rebuild the starting state of chapter 13 from scratch: `./scripts/bootstrap.sh 13`.

## Summary

- `AuthorizationPolicy` decides who may call a workload, by mTLS principal (`from`), method and
  path (`to`), and conditions (`when`). Sidecars and gateways enforce it.
- Evaluation order: `CUSTOM`, then `DENY` (any match denies), then `ALLOW` (any match allows).
  With an `ALLOW` policy present and none matching, the request is denied; an empty policy is
  default deny.
- Denials log `rbac_access_denied_matched_policy[...]`: `[none]` means no `ALLOW` matched; a named
  policy and rule means a `DENY` matched. A wrong principal fails silently and `analyze` can't see
  it.
- `RequestAuthentication` validates JWTs (`401` for a bad token) but lets requests without a token
  through. Require a token and a claim with an `AuthorizationPolicy`, and on a shared gateway use
  `DENY` scoped by host and port.
- Next, chapter 13 shows what the sidecars have been measuring all along: metrics, traces, and the
  Kiali graph.
