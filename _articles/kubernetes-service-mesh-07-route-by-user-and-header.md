---
layout: post
title: "Route by User and Header with Istio"
series: "Kubernetes Advanced: Service Mesh"
series_url: /kubernetes-service-mesh-series/
part: 7
date: 2026-10-22
author: Quan Huynh
subtitle: "Send one user to a new version with a header match, and learn why a header your app doesn't forward can never be matched one hop later."
tags: [kubernetes, istio, service-mesh, traffic-management, routing]
image: /assets/images/posts/kubernetes-service-mesh-07-route-by-user-and-header/cover.svg
---

Chapter 6 moved traffic to `reviews` v3 by percentage. A percentage is the right tool once a
version is ready for real users. Before that, a team usually wants something narrower: the QA
team should see v3 in production, with real data and real dependencies, while every customer
keeps seeing v1. A random 10% can't do that, and as chapter 6 showed, it can't even keep one
user on the same version from one page load to the next. Routing by *who sends the request* does
both.

Istio can match a request on its path, method, query parameters, and headers, and cookies travel
in the `Cookie` header. The QA case is a header match, and that part is easy. The part that
catches teams out is which headers exist at the proxy that makes the decision. In Book Store that
proxy is `productpage`'s sidecar, and it sees only the headers that `productpage` puts on its call
to `reviews`. This chapter shows a match that works, a match that can never fire, and why.

By the end of this chapter you will:

- Route one user to `reviews` v3 with a header match, and everyone else to v1.
- Read the rules Envoy built from the match with `istioctl proxy-config route`.
- Explain *header propagation*: why a header has to be forwarded by the app for a sidecar one hop
  later to see it.
- Fix a routing rule that never fires, without changing the app's code.

> **Code for this chapter.** The files are in
> [_resource/kubernetes-service-mesh/07-header-routing](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/kubernetes-service-mesh/07-header-routing).
> I tested them with Kind v0.33.0 (Kubernetes v1.37.0) and Istio 1.32.0 on macOS with Docker
> Desktop, and the command output in this chapter comes from those runs.

## Starting Point

Run every command from `_resource/kubernetes-service-mesh`, with the series' `istioctl` on your
PATH:

```sh
export PATH="$PWD/bin:$PATH"
```

The chapter needs the `reviews` `DestinationRule` from chapter 6 (subsets v1, v2, v3) and no
`VirtualService` for `reviews`. That's the state chapter 6's reset left. To build it from
scratch:

```sh
./scripts/bootstrap.sh 07
```

## How Book Store Knows Who You Are

Book Store has a "Sign in" button. It doesn't check passwords; any name works. Behind it,
`productpage` handles `POST /login`: it stores the user name in its session, a cookie signed by
the server, and redirects back to the page you came from. From then on, every call `productpage`
makes to another service, `reviews` included, carries a header with that name:

```text
end-user: qa-team
```

The header comes from `productpage`'s Python code, not from the browser or from Istio. A function
called `getForwardHeaders` builds the headers for every outgoing call: `end-user` from the
session, plus a fixed list of headers copied from the incoming request (`x-request-id`, the
tracing headers, `user-agent`, `cookie`, `authorization`, and `jwt`). Any other header on the
incoming request stays behind. Remember that list; the second half of the chapter depends on it.

`end-user` itself isn't on the copy list. `productpage` sets it only from the session, so a
client that sends its own `end-user` header can't choose a version that way.

## Send the QA Team to v3

`07-header-routing/virtualservice-reviews-qa.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookstore
spec:
  hosts:
    - reviews
  http:
    - name: qa-team
      match:
        - headers:
            end-user:
              exact: qa-team
      route:
        - destination:
            host: reviews
            subset: v3
    - name: default
      route:
        - destination:
            host: reviews
            subset: v1
```

Two rules, checked in order:

- `qa-team` matches when the request has an `end-user` header whose value is exactly `qa-team`,
  and sends it to subset v3. Besides `exact`, a header match can use `prefix` or `regex`.
  Istio requires the header name in a match to be lowercase.
- `default` has no `match`, so it matches everything. It must come last: a rule without a match
  placed first would catch every request, and the rules after it would never run.

Apply it and send requests without signing in:

```sh
kubectl apply -f 07-header-routing/virtualservice-reviews-qa.yaml
./scripts/count-versions.sh http://bookstore.local:8080 20
```

```text
virtualservice.networking.istio.io/reviews created
  20 200 reviews-v1 no-stars fast
```

Everyone without a name gets v1. Now sign in as `qa-team` with curl. `-d` posts the sign-in form;
`productpage` reads `username` and ignores the password. `-c` saves the session cookie from the
response to a file, the way a browser stores it:

```sh
curl -s --resolve bookstore.local:8080:127.0.0.1 -c /tmp/qa-cookies.txt \
  -d 'username=qa-team&passwd=anything' -o /dev/null -w "%{http_code}\n" \
  http://bookstore.local:8080/login
```

```text
302
```

`302` is the redirect that `/login` sends after it stores the name. Send the same requests with
the cookie. `CURL_OPTS` passes extra options to every curl the script runs, and `-b` with a file
name sends the cookies saved in that file:

```sh
CURL_OPTS="-b /tmp/qa-cookies.txt" ./scripts/count-versions.sh http://bookstore.local:8080 20
```

```text
  20 200 reviews-v3 stars fast
```

All 20 went to v3. In a browser (with the hosts entry from chapter 3), open
`http://bookstore.local:8080/productpage`, click "Sign in", and enter `qa-team` with any
password. The reviews show red stars on every refresh. Sign out, and they go back to no stars.

The decision happened in `productpage`'s sidecar, as in chapter 6. It received the outgoing call
with `end-user: qa-team` and matched it. The route table shows the rules it built. As in
chapter 6, the Python snippet trims the JSON, this time to each `reviews` route's name, header
match, and destination cluster:

```sh
istioctl proxy-config route deploy/productpage-v1 -n bookstore --name 9080 -o json | python3 -c '
import json, sys
for rc in json.load(sys.stdin):
    for vh in rc["virtualHosts"]:
        if vh["name"].startswith("reviews."):
            for r in vh["routes"]:
                print(r.get("name"), json.dumps(r["match"].get("headers", [])), r["route"]["cluster"])'
```

```text
qa-team [{"name": "end-user", "stringMatch": {"exact": "qa-team"}}] outbound|9080|v3|reviews.bookstore.svc.cluster.local
default [] outbound|9080|v1|reviews.bookstore.svc.cluster.local
```

One Envoy route per rule, in the same order, each pointing at a subset's cluster. Envoy uses the
first route that matches, so the order you write in YAML is the order the sidecar checks.

The figure follows the whole path, from the sign-in to the routing decision:

![Login sets a session cookie in the browser; on the next page load productpage reads the cookie and adds the header end-user qa-team to its call to reviews; productpage's sidecar matches the header and sends the call to reviews v3; a request without the cookie gets no end-user header and goes to reviews v1](/assets/images/posts/kubernetes-service-mesh-07-route-by-user-and-header/login-to-v3.svg)

A rule like this is only as trustworthy as the code that sets the header. Book Store's sign-in
has no password, so anyone can call themselves `qa-team`. In your own apps, route on a header
that the app derives from a real login, not on one a client can set directly.

## Break It: A Header That Never Arrives

The QA rule depends on a login. The team also wants a simpler switch for developers testing
from the command line: send `x-bookstore-preview: true` with any request, and see v3.
`07-header-routing/virtualservice-reviews-preview-header.yaml` adds a rule between the two:

```yaml
    - name: preview-header
      match:
        - headers:
            x-bookstore-preview:
              exact: "true"
      route:
        - destination:
            host: reviews
            subset: v3
```

(`"true"` is quoted so YAML reads it as text, not a boolean.) Apply it and send the header. The
script splits `CURL_OPTS` on spaces, so the header has no space after the colon:

```sh
kubectl apply -f 07-header-routing/virtualservice-reviews-preview-header.yaml
CURL_OPTS='-H x-bookstore-preview:true' ./scripts/count-versions.sh http://bookstore.local:8080 20
```

```text
virtualservice.networking.istio.io/reviews configured
  20 200 reviews-v1 no-stars fast
```

v1, every time. The rule itself is valid: `istioctl analyze -n bookstore` reports no issues, and
`productpage`'s sidecar has the `preview-header` route. To test the rule on its own, call
`reviews` from a test Pod inside the mesh and put the header on that call yourself. The
`bookstore` namespace has injection on, so the test Pod gets a sidecar, and every sidecar in the
mesh receives the same `reviews` routes as `productpage`'s:

```sh
kubectl -n bookstore run tester --image=docker.io/curlimages/curl:8.16.0 \
  --restart=Never --command -- sleep 3600
kubectl -n bookstore wait --for=condition=Ready pod/tester --timeout=90s
kubectl -n bookstore exec tester -c tester -- sh -c 'for i in 1 2 3 4 5; do
  curl -s -H "x-bookstore-preview: true" http://reviews:9080/reviews/0 | grep -o "reviews-v[0-9]"
done | sort | uniq -c'
```

```text
pod/tester created
pod/tester condition met
      5 reviews-v3
```

`-c tester` picks the app container; the Pod also has `istio-proxy`. All five calls went to v3.
The test Pod's own sidecar made the decision, with the same rules, on a request that carried the
header. So the rule works when the header is on the call it inspects. Through Book Store, the
header isn't there.

Follow the header. curl sends `x-bookstore-preview: true` to the gateway. The gateway routes on
host and path and forwards the request, header included, to `productpage`. The `productpage`
app receives it. Then the app makes a *new* HTTP request to `reviews`, and builds that request's
headers with `getForwardHeaders`. `x-bookstore-preview` isn't on its list, so the new request
doesn't carry it. `productpage`'s sidecar matches rules against that new request, finds no
header, and uses the default.

The top half of the figure shows that path. The bottom half is the fix from the next section.

![Two versions of the same call chain: on top, curl sends x-bookstore-preview to the gateway and productpage, but the productpage app does not copy it onto its call to reviews, so the sidecar sees no header and routes to v1; below, the app forwards the cookie header, the sidecar sees bookstore-preview=true and routes to v3](/assets/images/posts/kubernetes-service-mesh-07-route-by-user-and-header/header-propagation.svg)

This is *header propagation*: the app copying headers from the request it received onto the
requests it sends. It's a basic limit of a sidecar mesh. The sidecar sees each request, but it
can't tell which outgoing requests the app made because of which incoming one. Only the app knows
that. So any header that a routing rule matches one or more hops downstream must be copied by
every app in between. Chapter 13 meets the same limit with tracing headers, which is why most of
`productpage`'s list is tracing headers.

## Fix It Without Changing the Code

The proper fix is to add `x-bookstore-preview` to `productpage`'s forward list. That's a code
change and a release, often in another team's service. Until it ships, a header the app already
forwards can carry the signal. `productpage` forwards `cookie`, so a cookie the client sends
reaches the `reviews` call. Match on that instead.
`07-header-routing/virtualservice-reviews-preview-cookie.yaml` replaces the header rule with:

```yaml
    - name: preview-cookie
      match:
        - headers:
            cookie:
              regex: "^(.*;\\s*)?bookstore-preview=true(;.*)?$"
      route:
        - destination:
            host: reviews
            subset: v3
```

A `Cookie` header holds all cookies in one string, such as
`theme=dark; bookstore-preview=true`, so the rule uses a `regex`. It finds
`bookstore-preview=true` at the start of the header or after a `;`, followed by another `;` or
the end. A longer cookie name such as `old-bookstore-preview`, or a value such as `true2`, doesn't
match. (In the YAML string, `\\s` becomes the regex `\s`, any whitespace.)

Apply it and test three cases. `-b` with `name=value` text, instead of a file name, sends that
text as the cookie. The second case has no space after the `;` because the script splits
`CURL_OPTS` on spaces; the `\s*` in the regex covers the `; ` that browsers send.

```sh
kubectl apply -f 07-header-routing/virtualservice-reviews-preview-cookie.yaml
CURL_OPTS='-b bookstore-preview=true' ./scripts/count-versions.sh http://bookstore.local:8080 20
CURL_OPTS='-b theme=dark;bookstore-preview=true' ./scripts/count-versions.sh http://bookstore.local:8080 5
CURL_OPTS='-b bookstore-preview=false' ./scripts/count-versions.sh http://bookstore.local:8080 5
```

```text
virtualservice.networking.istio.io/reviews configured
  20 200 reviews-v3 stars fast
   5 200 reviews-v3 stars fast
   5 200 reviews-v1 no-stars fast
```

The cookie works alone and after another cookie, and `false` gets v1. A developer can now set the
cookie in the browser's developer tools and preview v3 without signing in.

The fix has costs. The match depends on a list in someone else's code: if the `productpage` team
ever stops forwarding cookies, the rule silently stops firing, exactly like the broken header
rule, and `istioctl analyze` won't notice. A regex over the whole `Cookie` header is easy to get
subtly wrong, so test the variants as above. And anyone who knows the cookie name can opt in.
That's fine for previewing a new star color, not for a feature that must stay private. For
anything long-lived, add the header to the app's forward list and match it exactly.

> **Note:** Matching at the gateway avoids the propagation problem, but only for the first hop.
> The gateway sees every header the client sends, so a gateway `VirtualService` could route on
> `x-bookstore-preview` to a second `productpage` version, given a `DestinationRule` with
> `productpage` subsets. (Book Store runs only `productpage` v1, so this chapter doesn't try it.)
> The gateway can't choose a `reviews` version, because that choice is made in `productpage`'s
> sidecar.

## Reset Before the Next Chapter

Delete the `VirtualService` and the test Pod, and keep the `DestinationRule`:

```sh
kubectl delete virtualservice reviews -n bookstore
kubectl -n bookstore delete pod tester
rm -f /tmp/qa-cookies.txt
```

To rebuild the starting state of chapter 8 from scratch: `./scripts/bootstrap.sh 08`.

## Summary

- A `VirtualService` rule can `match` on headers with `exact`, `prefix`, or `regex`. Rules run
  in order; put the default rule, with no match, last.
- `productpage` adds `end-user: <name>` to its outgoing calls after a sign-in, so a match on
  `end-user: qa-team` sends the QA team to v3 while everyone else gets v1. The rule is only as
  trustworthy as the code that sets the header.
- The routing decision for `reviews` happens in `productpage`'s sidecar, on the request
  `productpage` builds. A header the app doesn't copy onto that request can't be matched, and
  `istioctl analyze` can't warn you.
- Forward every header you route on, in every app along the path. Without a code change, match a
  header the app already forwards, such as `cookie`, and accept that the rule depends on the
  app's code and that anyone can set the cookie.
- Next, chapter 8 deals with slow and failing calls: timeouts, retries, and fault injection.
