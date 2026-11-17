---
layout: post
title: "Control Traffic Leaving the Mesh: ServiceEntry and the Egress Gateway"
series: "Kubernetes Advanced: Service Mesh"
series_url: /kubernetes-service-mesh-series/
part: 10
date: 2026-11-02
author: Quan Huynh
subtitle: "Block calls to unknown external hosts, allow one partner with a ServiceEntry, and send every call to it through a single, mutually authenticated exit point."
tags: [kubernetes, istio, service-mesh, egress, security]
image: /assets/images/posts/kubernetes-service-mesh-10-serviceentry-and-egress-gateway/cover.svg
---

Every chapter so far has dealt with traffic that enters the mesh or moves inside it. Most apps
also call out: a payment provider, a partner API, a cloud storage bucket. By default, Istio lets
a Pod call any address on the internet, and the sidecar has no rules for those calls: no route,
no retry, and often nothing in the log but an IP address and a byte count. For a security team,
that's two problems. Nobody can say which services talk to which outside hosts, and a
compromised Pod can send data anywhere.

The Book Store team now has a partner: a book catalog service run by another company. The
security team's requirements are simple to state. Only approved external hosts may be called.
Every call to the partner must leave through one place that logs it, so there's one audit trail
and, later, one place to put firewall rules. Istio has an object for each part: an outbound
traffic policy that blocks unknown hosts, a `ServiceEntry` that approves a host, and an *egress
gateway* that serves as the exit point.

By the end of this chapter you will:

- See how a sidecar handles a call to a host it doesn't know (`PassthroughCluster`), and block
  such calls with `REGISTRY_ONLY` (`BlackHoleCluster`).
- Register an external host with a `ServiceEntry` and get full HTTP visibility for its calls.
- Route calls to that host through the egress gateway with a two-hop `VirtualService`.
- Encrypt and authenticate the hop to the egress gateway with `ISTIO_MUTUAL`.
- Diagnose a `ServiceEntry` with the wrong protocol from the sidecar's listener.

> **Code for this chapter.** The files are in
> [_resource/kubernetes-service-mesh/10-egress](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/kubernetes-service-mesh/10-egress).
> I tested them with Kind v0.33.0 (Kubernetes v1.37.0) and Istio 1.32.0 on macOS with Docker
> Desktop, and the command output in this chapter comes from those runs.

## Starting Point

Run every command from `_resource/kubernetes-service-mesh`:

```sh
export PATH="$PWD/bin:$PATH"
```

The chapter needs Istio installed (with the egress gateway that chapter 2's install file turns
on) and Book Store in the mesh. Any state from chapter 3 on works. To build it from scratch:

```sh
./scripts/bootstrap.sh 10
```

Check that the egress gateway is running:

```sh
kubectl -n istio-system get deploy istio-egressgateway
```

The `READY` column should show `1/1`. If the Deployment doesn't exist, Istio was installed
without the egress gateway; rebuild with the `bootstrap.sh` command above.

## An "External" Service on Your Machine

A real partner API would need internet access, an account, and a rate limit that a tutorial
can't control. Instead, the partner catalog runs as a Docker container *outside* the Kind
cluster, on the same Docker network as the Kind nodes. To the mesh it is exactly like an outside
host: no sidecar, not a Kubernetes Service, reachable only by name over the network.

```sh
docker run -d --name partner-catalog --network kind \
  --network-alias catalog.partner.example \
  --restart unless-stopped docker.io/mccutchen/go-httpbin:v2.15.0
```

The container runs `go-httpbin`, the same image Istio's `httpbin` sample uses. It listens on port
8080 and echoes requests back. `--network kind` puts it on the Kind nodes' Docker network, and
`--network-alias` gives it the DNS name `catalog.partner.example` there. Pods can resolve that
name because Kubernetes DNS forwards unknown names to the node, and the node asks Docker. (The
`.example` domain is reserved for documentation, so it can never clash with a real site.)
`--restart unless-stopped` brings the container back if Docker restarts in the middle of the
chapter.

The caller is a small client Pod in `bookstore`, defined in `10-egress/tester.yaml`. It only
runs `sleep`, so you can run curl in it with `kubectl exec`, and it gets a sidecar like every
Pod in the namespace. Deploy it and call the partner:

```sh
kubectl apply -f 10-egress/tester.yaml
kubectl -n bookstore rollout status deploy/tester
kubectl -n bookstore exec deploy/tester -c tester -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://catalog.partner.example:8080/get
```

```text
serviceaccount/tester created
deployment.apps/tester created
Waiting for deployment "tester" rollout to finish: 0 of 1 updated replicas are available...
deployment "tester" successfully rolled out
200
```

The call works. Now look at what the sidecar recorded:

```sh
kubectl -n bookstore logs deploy/tester -c istio-proxy --tail=1
```

```text
[2026-11-17T01:55:40.000Z] "- - -" 0 - - - "-" 95 475 2 - "-" "-" "-" "-" "172.21.0.5:8080" PassthroughCluster 10.244.2.25:49472 172.21.0.5:8080 10.244.2.25:49464 - -
```

No method, no path, no status: `"- - -"` is a TCP connection, 95 bytes out and 475 back, to the
IP `172.21.0.5`. The cluster is `PassthroughCluster`, the catch-all that Istio gives every
sidecar for destinations it knows nothing about (chapter 2 showed it on the outbound capture
port, 15001). It forwards the bytes and understands none of them. This is Istio's default
outbound policy, `ALLOW_ANY`: any destination is allowed, and the sidecar sees only an IP and a
byte count.

## Block Unknown Hosts: REGISTRY_ONLY

The opposite policy is `REGISTRY_ONLY`: a sidecar only sends traffic to hosts in Istio's *service
registry*, the list of everything `istiod` knows about. Kubernetes Services are in it
automatically. External hosts are not.

You can set the policy for the whole mesh in the install file
(`meshConfig.outboundTrafficPolicy.mode`), which means running `istioctl install` again. A
`Sidecar` object sets it for one namespace with a plain `kubectl apply`, which is easier to try
and to undo. `10-egress/sidecar-registry-only.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: bookstore
spec:
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
```

A `Sidecar` object tunes the configuration of the sidecars in its namespace. One without a
`workloadSelector` applies to every Pod in the namespace. A namespace should have only one of
those, and by convention it's named `default`. Apply it and call the partner again:

```sh
kubectl apply -f 10-egress/sidecar-registry-only.yaml
kubectl -n bookstore exec deploy/tester -c tester -- \
  curl -sS -o /dev/null -w "%{http_code}\n" http://catalog.partner.example:8080/get
kubectl -n bookstore logs deploy/tester -c istio-proxy --tail=1
```

```text
sidecar.networking.istio.io/default created
000
curl: (56) Recv failure: Connection reset by peer
command terminated with exit code 56
[2026-11-17T01:56:22.564Z] "- - -" 0 UH - - "-" 0 0 0 - "-" "-" "-" "-" "-" BlackHoleCluster - 172.21.0.5:8080 10.244.2.25:34726 - -
```

Blocked. The sidecar sent the connection to `BlackHoleCluster`, a cluster with no endpoints, so
Envoy logged `UH` (no healthy upstream, the flag from chapter 5's table) and closed the
connection. The app sees a reset connection, curl's exit code 56. Book Store itself keeps
working, because every service it calls is a Kubernetes Service:

```sh
./scripts/count-versions.sh http://bookstore.local:8080 10
```

```text
   4 200 reviews-v1 no-stars fast
   3 200 reviews-v3 stars fast
   3 200 reviews-v2 stars fast
```

All ten requests return `200`. The policy blocks only hosts that Istio doesn't know.

## Approve a Host: ServiceEntry

A `ServiceEntry` adds an external host to the service registry.
`10-egress/serviceentry-partner-catalog.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: partner-catalog
  namespace: bookstore
spec:
  hosts:
    - catalog.partner.example
  location: MESH_EXTERNAL
  resolution: DNS
  ports:
    - number: 8080
      name: http
      protocol: HTTP
```

- `hosts`: the name clients use.
- `location: MESH_EXTERNAL`: the host is outside the mesh. It has no sidecar, so Istio won't try
  to use mesh mTLS with it.
- `resolution: DNS`: Envoy resolves the name itself and connects to the addresses it gets back.
- `ports`: the port and its protocol. `HTTP` tells the sidecar to parse the traffic as HTTP, the
  same job the port name `http` does on a Kubernetes Service.

```sh
kubectl apply -f 10-egress/serviceentry-partner-catalog.yaml
kubectl -n bookstore exec deploy/tester -c tester -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://catalog.partner.example:8080/get
kubectl -n bookstore logs deploy/tester -c istio-proxy --tail=1
```

```text
serviceentry.networking.istio.io/partner-catalog created
200
[2026-11-17T01:56:29.883Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 1153 4 3 "-" "curl/8.16.0" "2fcacac2-9a8f-41df-af60-5a54f737d53e" "catalog.partner.example:8080" "172.21.0.5:8080" outbound|8080||catalog.partner.example 10.244.2.25:57462 172.21.0.5:8080 10.244.2.25:57456 - default
```

Allowed, and now a real HTTP log line: method, path, status, host, and a named cluster,
`outbound|8080||catalog.partner.example`. Because the sidecar now parses these calls as HTTP,
the tools from chapters 8 and 9 apply to this host: you could set a timeout, retries, or outlier
detection on calls to the partner. Its calls are also counted in the sidecar's request metrics
under the partner's host name, the metrics chapter 13 explains.

The figure puts the three states side by side: the same call passed through as TCP, dropped,
and then allowed as HTTP.

![Three egress states side by side: with ALLOW_ANY the call to catalog.partner.example passes through as anonymous TCP via PassthroughCluster; with REGISTRY_ONLY the same call is dropped by BlackHoleCluster; with REGISTRY_ONLY plus a ServiceEntry the call is allowed and appears as a full HTTP request to the cluster outbound|8080||catalog.partner.example](/assets/images/posts/kubernetes-service-mesh-10-serviceentry-and-egress-gateway/egress-states.svg)

## One Exit Point: the Egress Gateway

Right now each Pod calls the partner directly from its own node. The security team wants every
call to leave through one place. The egress gateway, which chapter 2's install created and
nothing has used yet, is an Envoy that serves as that place. It's the mirror image of the
ingress gateway from chapter 3, configured with the same `Gateway` and `VirtualService` objects.

Getting traffic through it takes two hops, and one `VirtualService` describes both:

![Through the egress gateway: the tester Pod's sidecar matches rule to-egress-gateway (gateways: mesh, port 8080) and sends the call for catalog.partner.example over mesh mTLS to port 443 of the istio-egressgateway Service; the egress gateway matches rule to-partner (gateways: partner-egress, port 443) and sends plain HTTP to catalog.partner.example port 8080 outside the cluster; a NetworkPolicy should block direct egress from Pods so the gateway is the only exit](/assets/images/posts/kubernetes-service-mesh-10-serviceentry-and-egress-gateway/egress-two-hops.svg)

The figure shows where this section ends up, with mesh mTLS on the first hop (port 443). The
first version below uses plain HTTP on port 80 for that hop, and the next section secures it.

`10-egress/egress-gateway.yaml` (first version):

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: partner-egress
  namespace: bookstore
spec:
  selector:
    istio: egressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - catalog.partner.example
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: partner-catalog
  namespace: bookstore
spec:
  hosts:
    - catalog.partner.example
  gateways:
    - mesh
    - partner-egress
  http:
    - name: to-egress-gateway
      match:
        - gateways:
            - mesh
          port: 8080
      route:
        - destination:
            host: istio-egressgateway.istio-system.svc.cluster.local
            port:
              number: 80
    - name: to-partner
      match:
        - gateways:
            - partner-egress
          port: 80
      route:
        - destination:
            host: catalog.partner.example
            port:
              number: 8080
```

- The `Gateway` selects the egress gateway Pods by their label, `istio: egressgateway`, and
  opens port 80 of their Service for the partner's host name. As with the ingress gateway in
  chapter 3, Envoy listens on the Pod port behind it, 8080.
- The `VirtualService` is attached to two gateways at once. `mesh` means "the sidecars", as in
  chapter 6. `partner-egress` is the egress gateway.
- Rule `to-egress-gateway` matches only at the sidecars (`gateways: [mesh]`), for calls to port
  8080, and sends them to the egress gateway's Service. The Service is in another namespace, so
  the destination uses its full name.
- Rule `to-partner` matches only at the egress gateway, on its port 80, and sends the call to the
  real partner on port 8080.

The `gateways` condition in each `match` is what keeps the two hops apart. In this file the
ports differ as well (8080 at the sidecar, 80 at the gateway), but often they don't: an app
calls a partner on port 80, and the gateway listens on 80 too. Then a rule without `gateways`
matches at both places, and the egress gateway sends the request back to itself. Always pin
each rule to its gateway.

The `Gateway` host is the full name `catalog.partner.example`. I first tried naming the container
`partner-catalog` and using that short name, and `kubectl apply` rejected the `Gateway` with
`short names (non FQDN) are not allowed`. External hosts on a `Gateway` need a fully qualified
name, which is why the container has a network alias with dots in it.

```sh
kubectl apply -f 10-egress/egress-gateway.yaml
kubectl -n bookstore exec deploy/tester -c tester -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://catalog.partner.example:8080/get
kubectl -n bookstore logs deploy/tester -c istio-proxy --tail=1
kubectl -n istio-system logs deploy/istio-egressgateway --tail=1
```

```text
gateway.networking.istio.io/partner-egress created
virtualservice.networking.istio.io/partner-catalog created
200
[2026-11-17T01:56:42.385Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 1384 7 6 "-" "curl/8.16.0" "f9062be7-d114-4b04-9615-840fdb46ecfe" "catalog.partner.example:8080" "10.244.2.5:8080" outbound|80||istio-egressgateway.istio-system.svc.cluster.local 10.244.2.25:37854 172.21.0.5:8080 10.244.2.25:60806 - to-egress-gateway
[2026-11-17T01:56:42.386Z] "GET /get HTTP/2" 200 - via_upstream - "-" 0 1384 3 2 "10.244.2.25" "curl/8.16.0" "f5f57bef-8ecb-4d29-9292-ed764a993154" "catalog.partner.example:8080" "172.21.0.5:8080" outbound|8080||catalog.partner.example 10.244.2.5:48544 10.244.2.5:8080 10.244.2.25:37854 - to-partner
```

Read the two lines as the two hops. The rule name at the end of each line says which rule
handled it. The tester's sidecar matched `to-egress-gateway` and sent the call to
`10.244.2.5:8080`, the egress gateway Pod. The egress gateway matched `to-partner` and sent it to
`172.21.0.5:8080`, the partner. Its `x-forwarded-for` field holds the tester Pod's IP,
`10.244.2.25`, so the gateway's log records which Pod made each call. That log is the audit trail
the security team asked for.

## Secure the Hop to the Gateway: ISTIO_MUTUAL

The first hop, from the sidecar to the egress gateway, is plain HTTP on port 80. The gateway's
log line above shows it: the field just before the rule name, where the SNI of a TLS connection
goes, is `-`. Inside the mesh that's a weak spot. The gateway can't prove who called it (an IP
in `x-forwarded-for` is only a claim), and the request crosses the cluster network unencrypted.
Chapter 4 mentioned the fix, the `ISTIO_MUTUAL` TLS mode: the sidecar and the gateway
authenticate each other with the certificates `istiod` gives every proxy (chapter 11 explains
those certificates).

`10-egress/egress-gateway-mtls.yaml` replaces the first version. It changes the `Gateway` server,
adds a `DestinationRule`, and changes the two `VirtualService` rules (the file has the complete
objects):

```yaml
# Gateway partner-egress: the server moves to port 443 and requires mesh mTLS
# ... apiVersion, kind, and metadata as in egress-gateway.yaml
spec:
  # ... selector as in egress-gateway.yaml
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      hosts:
        - catalog.partner.example
      tls:
        mode: ISTIO_MUTUAL
---
# DestinationRule (new): how sidecars connect to the egress gateway for this host
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: egressgateway-for-partner
  namespace: bookstore
spec:
  host: istio-egressgateway.istio-system.svc.cluster.local
  subsets:
    - name: partner-catalog
      trafficPolicy:
        portLevelSettings:
          - port:
              number: 443
            tls:
              mode: ISTIO_MUTUAL
              sni: catalog.partner.example
---
# VirtualService partner-catalog: hop 1 goes to that subset on port 443; hop 2 matches 443
# ... apiVersion, kind, and metadata as in egress-gateway.yaml
spec:
  # ... hosts and gateways as in egress-gateway.yaml
  http:
    - name: to-egress-gateway
      match:
        - gateways:
            - mesh
          port: 8080
      route:
        - destination:
            host: istio-egressgateway.istio-system.svc.cluster.local
            subset: partner-catalog
            port:
              number: 443
    - name: to-partner
      match:
        - gateways:
            - partner-egress
          port: 443
      route:
        - destination:
            host: catalog.partner.example
            port:
              number: 8080
```

- The `Gateway` server moves to port 443 and accepts only `ISTIO_MUTUAL` connections: TLS where the
  client must present a mesh certificate. There's no `credentialName`, because the certificates
  come from `istiod`, not from a Secret.
- The `DestinationRule` tells sidecars to connect to the egress gateway with mesh mTLS, sending
  the partner's name as SNI so the gateway can pick the right server (chapter 4's SNI matching,
  from the other side). The settings sit in a subset, so they apply only to traffic that a route
  sends to that subset, not to every connection to the egress gateway. A second partner would get
  a subset of its own, with its own SNI.
- The `VirtualService`'s first rule routes to subset `partner-catalog` of the egress gateway on
  port 443, and the second rule matches the gateway's new port, 443.

```sh
kubectl apply -f 10-egress/egress-gateway-mtls.yaml
kubectl -n bookstore exec deploy/tester -c tester -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://catalog.partner.example:8080/get
kubectl -n bookstore logs deploy/tester -c istio-proxy --tail=1
kubectl -n istio-system logs deploy/istio-egressgateway --tail=1
```

```text
gateway.networking.istio.io/partner-egress configured
destinationrule.networking.istio.io/egressgateway-for-partner created
virtualservice.networking.istio.io/partner-catalog configured
200
[2026-11-17T01:57:42.335Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 2956 5 5 "-" "curl/8.16.0" "40b96684-3c75-4ff8-92bc-c894b62da39c" "catalog.partner.example:8080" "10.244.2.5:8443" outbound|443|partner-catalog|istio-egressgateway.istio-system.svc.cluster.local 10.244.2.25:46032 172.21.0.5:8080 10.244.2.25:33176 - to-egress-gateway
[2026-11-17T01:57:42.339Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 2956 1 1 "10.244.2.25" "curl/8.16.0" "abb9adb8-8248-4a37-910a-062db0e678bf" "catalog.partner.example:8080" "172.21.0.5:8080" outbound|8080||catalog.partner.example 10.244.2.5:55940 10.244.2.5:8443 10.244.2.25:46032 catalog.partner.example to-partner
```

The app still calls plain `http://catalog.partner.example:8080`; nothing changed for it. The first
hop now goes to the gateway Pod's port `8443` (the Pod port behind Service port 443) through the
cluster `outbound|443|partner-catalog|istio-egressgateway...`, the subset with mesh mTLS. The
gateway's line now shows the SNI it received, `catalog.partner.example`, where the first version
had `-`.

The last hop, from the gateway to the partner, is still plain HTTP, because this partner speaks
plain HTTP. A real partner API would use HTTPS. The egress gateway can then *originate* TLS for
that last hop: a `DestinationRule` for the partner's host with `tls.mode: SIMPLE` makes the
gateway open the TLS connection itself. Apps keep sending plain HTTP inside the mesh, and the
gateway encrypts on the way out. (I didn't run this variant here, because the lab partner has
no HTTPS port.)

> **Note:** The egress gateway is an exit point by convention, not a wall. The routing rules live
> in the sidecars, so a Pod without a sidecar never sees them (chapter 6 showed the same for
> routing), and neither does a process that gets around its sidecar's traffic capture. Both can
> still reach the partner directly. To enforce the exit point, add a Kubernetes NetworkPolicy (or
> a cloud firewall rule) that allows outbound traffic to external networks only from the egress
> gateway Pods. Istio's documentation says the same: the egress gateway needs that second layer.

## Break It: The Wrong Protocol in a ServiceEntry

A teammate edits the `ServiceEntry` and, assuming partner APIs always use TLS, sets the port's
protocol to `HTTPS`. The partner on port 8080 speaks plain HTTP:

```sh
kubectl -n bookstore patch serviceentry partner-catalog --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/protocol","value":"HTTPS"},{"op":"replace","path":"/spec/ports/0/name","value":"https"}]'
kubectl -n bookstore exec deploy/tester -c tester -- \
  curl -sS -o /dev/null -w "%{http_code}\n" http://catalog.partner.example:8080/get
kubectl -n bookstore logs deploy/tester -c istio-proxy --tail=1
istioctl analyze -n bookstore
```

```text
serviceentry.networking.istio.io/partner-catalog patched
curl: (56) Recv failure: Connection reset by peer
000
command terminated with exit code 56
[2026-11-17T01:59:36.664Z] "- - -" 0 UH - - "-" 0 0 0 - "-" "-" "-" "-" "-" BlackHoleCluster - 172.21.0.5:8080 10.244.2.26:37588 - -
✔ No validation issues found when analyzing namespace: bookstore.
```

The call fails exactly as if there were no `ServiceEntry` at all: `BlackHoleCluster`. (I ran
this section a second time, so the tester Pod's IP differs from earlier lines.) The
request never left the tester's sidecar, so it never reached the egress gateway, and the
`VirtualService` routes didn't run. And `analyze` is happy, because the configuration is valid;
it's just wrong about the partner.

The clue is in the sidecar's listener for port 8080:

```sh
istioctl proxy-config listener deploy/tester -n bookstore --port 8080
```

```text
ADDRESSES PORT MATCH                        DESTINATION
0.0.0.0   8080 ALL                          Non-HTTP/Non-TCP
0.0.0.0   8080 SNI: catalog.partner.example Cluster: outbound|8080||catalog.partner.example
```

With `protocol: HTTPS`, the sidecar expects TLS on port 8080 and picks the destination by the SNI
in the TLS handshake, the same way chapter 4's gateway did for `PASSTHROUGH`. curl sends plain HTTP,
which has no SNI, so nothing matches and `REGISTRY_ONLY` sends it to the black hole. Put the
protocol back and the listener parses HTTP again:

```sh
kubectl -n bookstore patch serviceentry partner-catalog --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/protocol","value":"HTTP"},{"op":"replace","path":"/spec/ports/0/name","value":"http"}]'
istioctl proxy-config listener deploy/tester -n bookstore --port 8080
kubectl -n bookstore exec deploy/tester -c tester -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://catalog.partner.example:8080/get
```

```text
serviceentry.networking.istio.io/partner-catalog patched
ADDRESSES PORT MATCH                                DESTINATION
0.0.0.0   8080 Trans: raw_buffer; App: http/1.1,h2c Route: 8080
0.0.0.0   8080 ALL                                  Non-HTTP/Non-TCP
200
```

The HTTP row is back, and the call returns `200`. The rule to take from this: the `protocol` in a
`ServiceEntry` describes what the *client sends to the sidecar*, not what the partner advertises.
An app that speaks plain HTTP needs `HTTP`, even if the gateway encrypts the last hop. An app that
does its own TLS needs `TLS` or `HTTPS`. `istioctl analyze` can't catch a mismatch, because it
doesn't know what the app sends; `istioctl proxy-config listener` shows what the sidecar expects.

## Reset Before the Next Chapter

Remove everything from this chapter, including the partner container:

```sh
kubectl delete -f 10-egress/egress-gateway-mtls.yaml -f 10-egress/serviceentry-partner-catalog.yaml \
  -f 10-egress/sidecar-registry-only.yaml -f 10-egress/tester.yaml
docker rm -f partner-catalog
```

```text
gateway.networking.istio.io "partner-egress" deleted
destinationrule.networking.istio.io "egressgateway-for-partner" deleted
virtualservice.networking.istio.io "partner-catalog" deleted
serviceentry.networking.istio.io "partner-catalog" deleted
sidecar.networking.istio.io "default" deleted
serviceaccount "tester" deleted
deployment.apps "tester" deleted
partner-catalog
```

`kind delete cluster` doesn't remove the container, because it isn't part of the cluster, and
`--restart unless-stopped` starts it again with Docker. So remove it yourself if you skip this
step. To rebuild the starting state of chapter 11 from scratch: `./scripts/bootstrap.sh 11`.

## Summary

- By default (`ALLOW_ANY`), a sidecar forwards calls to unknown hosts as anonymous TCP through
  `PassthroughCluster`. `REGISTRY_ONLY` drops them in `BlackHoleCluster`; a `Sidecar` object sets
  it per namespace.
- A `ServiceEntry` adds an external host to the registry. With `protocol: HTTP`, its calls become
  full HTTP requests with routing, retries, metrics, and log lines.
- An egress gateway is an exit point. One `VirtualService` bound to `mesh` and to the egress
  `Gateway` routes the two hops, with `match.gateways` deciding which rule applies where.
- `ISTIO_MUTUAL` on the egress `Gateway` plus a `DestinationRule` encrypts and authenticates the
  hop from the sidecar to the gateway. Enforcing the exit point also needs a NetworkPolicy or
  firewall.
- A `ServiceEntry` port protocol must match what the client sends. A wrong one fails like a
  missing `ServiceEntry`, `istioctl analyze` doesn't notice, and `istioctl proxy-config listener`
  shows why. Next, chapter 11 covers mutual TLS between the services inside the mesh, and the
  certificates behind it.
