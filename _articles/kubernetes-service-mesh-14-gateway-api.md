---
layout: post
title: "The Kubernetes Gateway API with Istio"
series: "Kubernetes Advanced: Service Mesh"
series_url: /kubernetes-service-mesh-series/
part: 14
date: 2026-11-15
author: Quan Huynh
subtitle: "Rebuild the gateway, routes, HTTPS, and canary from earlier chapters with the Kubernetes Gateway API, map each Istio object to its replacement, and fix a route that crosses namespaces."
tags: [kubernetes, istio, service-mesh, gateway-api, ingress]
image: /assets/images/posts/kubernetes-service-mesh-14-gateway-api/cover.svg
---

Chapters 3 to 6 configured traffic with Istio's own objects: `Gateway`, `VirtualService`, and
`DestinationRule`. They work, and most Istio documentation and clusters still use them. But only
Istio reads them. A team that moves Book Store to another mesh or ingress controller rewrites every
one of those files.

The Kubernetes *Gateway API* is a standard set of routing objects, maintained by Kubernetes SIG
Network and implemented by Istio, Envoy Gateway, Cilium, NGINX, and others. The Istio project
has said the Gateway API will become its default API for traffic management. So even if your
cluster runs on Istio's API today, you will read and write these objects sooner or later.

This chapter rebuilds earlier work with the Gateway API, next to the existing setup so you can
compare the two: a second gateway at `http://bookstore.local:9080`, chapter 3's routes, chapter
4's HTTPS, and chapter 6's canary. Then it breaks a route that crosses namespaces, which runs into
a permission rule that Istio's API doesn't have.

By the end of this chapter you will:

- Install the Gateway API CRDs and create a `Gateway` that deploys its own proxy.
- Route with an `HTTPRoute`, at the edge and inside the mesh.
- Run a canary with weighted `backendRefs` instead of subsets.
- Read a route's `status` to see why it isn't working, and fix a cross-namespace reference with a
  `ReferenceGrant`.
- Map each Istio object to its Gateway API counterpart, and know what still needs Istio's APIs.

> **Code for this chapter.** The files are in
> [_resource/kubernetes-service-mesh/14-gateway-api](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/kubernetes-service-mesh/14-gateway-api).
> I tested them with Kind v0.33.0 (Kubernetes v1.37.0), Istio 1.32.0, and Gateway API v1.6.1 on
> macOS with Docker Desktop, and the command output in this chapter comes from those runs.

## Starting Point

Run every command from `_resource/kubernetes-service-mesh`:

```sh
export PATH="$PWD/bin:$PATH"
```

The chapter starts where chapter 13 ended: Istio, Book Store at `http://bookstore.local:8080`
through chapter 3's `Gateway` and `VirtualService`, the `reviews` `DestinationRule` from chapter 6,
and `STRICT` mutual TLS in `bookstore` from chapter 11. It also needs the certificates from
chapter 4 in `certs/` (run `./scripts/make-certs.sh` if you skipped chapter 4). To build the
cluster state from scratch: `./scripts/bootstrap.sh 14`.

## Two APIs, Two Object Models

![Object model side by side: with the Istio API, an istio-ingressgateway Deployment is installed separately, a Gateway object selects it by label, a VirtualService attaches to the Gateway by name, and a DestinationRule defines subsets; with the Gateway API, a GatewayClass named istio points at Istio's controller, a Gateway of that class makes Istio create its own Deployment and Service, an HTTPRoute attaches to the Gateway with parentRefs, and versions are separate Services](/assets/images/posts/kubernetes-service-mesh-14-gateway-api/object-models.svg)

The figure puts the two object models side by side. The biggest difference is who owns the proxy.
Istio's `Gateway` configures a proxy that was installed separately (chapter 2's
`istio-ingressgateway`). A Gateway API `Gateway` *is* the proxy: create one, and Istio deploys a
Deployment and a Service for it. Delete it, and they're gone.

The Gateway API also gives each object an owner. Chapter 3 split the work between a platform team
and app teams; the Gateway API builds that split into its objects:

- A `GatewayClass` says which controller handles Gateways of that class. Istio registers one named
  `istio`. The infrastructure provider owns it.
- A `Gateway` says which ports, protocols, and host names to listen on. The platform team owns it.
- An `HTTPRoute` says which requests go where. Each app team owns its own routes.

In this chapter, `Gateway` means the Gateway API object (`gateway.networking.k8s.io/v1`) unless the
text says Istio's `Gateway`.

## Install the Gateway API CRDs

The Gateway API objects aren't built into Kubernetes; they're CRDs you install. Istio 1.32's
documentation uses version v1.6.1 of the standard channel:

```sh
kubectl apply --server-side \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
kubectl get gatewayclass
```

```text
customresourcedefinition.apiextensions.k8s.io/backendtlspolicies.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/gatewayclasses.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/gateways.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/grpcroutes.gateway.networking.k8s.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/httproutes.gateway.networking.k8s.io serverside-applied
...
NAME           CONTROLLER                    ACCEPTED   AGE
istio          istio.io/gateway-controller   True       3s
istio-remote   istio.io/unmanaged-gateway    True       3s
```

`--server-side` is needed because some of these CRDs are too large for a normal `kubectl apply`.
As soon as the CRDs exist, `istiod` registers the `istio` GatewayClass. (`istio-remote` is for
multi-cluster setups; ignore it.)

## A Gateway That Deploys Its Own Proxy

On a cloud, the Gateway's Service would be a `LoadBalancer`. On Kind, it has to be a NodePort on
30090, the third port chapter 1's Kind config mapped (to `localhost:9080`). Istio lets you patch
the generated Service through a ConfigMap referenced from the Gateway's `infrastructure` field.
`14-gateway-api/gateway.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bookstore-gw-options
  namespace: bookstore
data:
  service: |
    spec:
      type: NodePort
      ports:
        - name: http
          port: 80
          nodePort: 30090
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: bookstore-gw
  namespace: bookstore
spec:
  gatewayClassName: istio
  infrastructure:
    parametersRef:
      group: ""
      kind: ConfigMap
      name: bookstore-gw-options
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      hostname: bookstore.local
      allowedRoutes:
        namespaces:
          from: Same
```

- `gatewayClassName: istio` hands the Gateway to Istio.
- `listeners` replace the `servers` of Istio's `Gateway`: a port, a protocol, and a host name.
- `allowedRoutes` says which namespaces may attach routes to this listener. `Same`, the default,
  means only `bookstore`.
- `infrastructure.parametersRef` points at the ConfigMap. Its `service` key is merged into the
  generated Service. The reference has no namespace field, so the ConfigMap must sit in the
  Gateway's namespace.

Apply the file, wait until Istio reports the Gateway as programmed and its Deployment as rolled
out, then look at both objects:

```sh
kubectl apply -f 14-gateway-api/gateway.yaml
kubectl -n bookstore wait --for=condition=Programmed gateway/bookstore-gw --timeout=120s
kubectl -n bookstore rollout status deploy/bookstore-gw-istio
kubectl -n bookstore get gateway bookstore-gw
kubectl -n bookstore get svc bookstore-gw-istio
```

```text
configmap/bookstore-gw-options created
gateway.gateway.networking.k8s.io/bookstore-gw created
gateway.gateway.networking.k8s.io/bookstore-gw condition met
deployment "bookstore-gw-istio" successfully rolled out
NAME           CLASS   ADDRESS                                          PROGRAMMED   AGE
bookstore-gw   istio   bookstore-gw-istio.bookstore.svc.cluster.local   True         6s
NAME                 TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                        AGE
bookstore-gw-istio   NodePort   10.96.95.150   <none>        15021:31266/TCP,80:30090/TCP   6s
```

Istio created `bookstore-gw-istio` (the Gateway's name plus the class name) in `bookstore`, the
Gateway's namespace, with port 80 on node port 30090. `PROGRAMMED True` means the proxy is
running and configured. The `15021` port is the health-check port from chapter 3. The gateway has
no routes yet, so a request gets a `404`:

```sh
curl -si --resolve bookstore.local:9080:127.0.0.1 http://bookstore.local:9080/productpage | head -3
```

```text
HTTP/1.1 404 Not Found
date: Tue, 17 Nov 2026 02:26:28 GMT
server: istio-envoy
```

Chapter 3 saw the same `404` from the Istio gateway with a `Gateway` and no `VirtualService`.

## Routes: HTTPRoute

`14-gateway-api/httproute.yaml` is chapter 3's `VirtualService`, rewritten:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bookstore
  namespace: bookstore
spec:
  parentRefs:
    - name: bookstore-gw
  hostnames:
    - bookstore.local
  rules:
    - matches:
        - path:
            type: Exact
            value: /
      filters:
        - type: RequestRedirect
          requestRedirect:
            path:
              type: ReplaceFullPath
              replaceFullPath: /productpage
            statusCode: 301
    - matches:
        - path:
            type: Exact
            value: /productpage
        - path:
            type: PathPrefix
            value: /static
        - path:
            type: Exact
            value: /login
        - path:
            type: Exact
            value: /logout
        - path:
            type: PathPrefix
            value: /api/v1/products
      backendRefs:
        - name: productpage
          port: 9080
```

The shape is close to a `VirtualService`:

- `parentRefs` replaces `gateways`. A name without a namespace means a Gateway in the route's own
  namespace.
- `hostnames` replaces `hosts`.
- `Exact` and `PathPrefix` replace `exact` and `prefix`.
- The redirect becomes a `RequestRedirect` filter on the rule.
- `backendRefs` names the Service and port directly, with no `destination` wrapper.

Two differences matter when you translate routes by hand. First, Gateway API `PathPrefix` matches
whole path segments, so `/static` matches `/static/img/izzy.png` but not `/staticfoo`. Chapter 3
wrote `prefix: /static/` with a trailing slash to get the same effect from Istio's plain string
prefix. Second, rule order doesn't decide which rule wins. Chapter 3's rules were checked top to
bottom; the Gateway API picks the most specific match instead (an exact path before a prefix, a
longer prefix before a shorter one). This route's matches don't overlap, so the result is the same
here.

Apply the route, then request the page, the redirect, and the reviews API through port 9080:

```sh
kubectl apply -f 14-gateway-api/httproute.yaml
curl -s --resolve bookstore.local:9080:127.0.0.1 http://bookstore.local:9080/productpage | grep -o "<title>.*</title>"
curl -si --resolve bookstore.local:9080:127.0.0.1 http://bookstore.local:9080/ | head -2
./scripts/count-versions.sh http://bookstore.local:9080 20
```

```text
httproute.gateway.networking.k8s.io/bookstore created
<title>Simple Bookstore App</title>
HTTP/1.1 301 Moved Permanently
location: http://bookstore.local:9080/productpage
   8 200 reviews-v1 no-stars fast
   7 200 reviews-v2 stars fast
   5 200 reviews-v3 stars fast
```

The page, the `301` redirect, and the API all work through the new gateway on port 9080, and the
reviews still spread across all three versions. Chapter 3's setup keeps serving 8080. Running both
gateways side by side is also how a migration can work in a real cluster: move one host to the
new gateway, check it, and keep the old one as the fallback until you're done.

Every Gateway API object reports its state in `status`. For a route, `status.parents` has one entry
per parent it tried to attach to:

```sh
kubectl -n bookstore get httproute bookstore -o jsonpath='{range .status.parents[*]}{.parentRef.name}{": "}{range .conditions[*]}{.type}={.status} ({.reason}) {end}{"\n"}{end}'
```

```text
bookstore-gw: Accepted=True (Accepted) ResolvedRefs=True (ResolvedRefs)
```

`Accepted` means the Gateway took the route. `ResolvedRefs` means every backend it names exists and
may be used. Make this the first thing you check, the way `istioctl analyze` was for Istio's API.

## HTTPS: Chapter 4 Again

Chapter 4 added an HTTPS server to Istio's `Gateway`. The Gateway API version is a second
listener, and the certificate reference is the part that differs. `14-gateway-api/gateway-https.yaml`
is `gateway.yaml` with this listener added:

```yaml
    - name: https
      port: 443
      protocol: HTTPS
      hostname: bookstore.local
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: bookstore-local-tls
```

`mode: Terminate` is Istio's `SIMPLE`: the gateway decrypts TLS and routes plain HTTP.
`certificateRefs` replaces `credentialName`, and a reference without a namespace means a Secret
in the Gateway's own namespace, `bookstore`. Chapter 4's rule was different: the Secret had to sit
with the gateway Pods in `istio-system`, whatever namespace the `Gateway` object lived in. Here
the two namespaces are the same, because Istio deployed the proxy next to the Gateway.

Kind maps no host port to this listener, so create the Secret, apply the file, and test HTTPS
through a port-forward to the generated Service. The `port-forward` doesn't return until you stop
it:

```sh
kubectl -n bookstore create secret tls bookstore-local-tls \
  --cert=certs/bookstore.local.crt --key=certs/bookstore.local.key
kubectl apply -f 14-gateway-api/gateway-https.yaml
kubectl -n bookstore port-forward svc/bookstore-gw-istio 9443:443
```

In a second terminal, in the same folder, request the page over HTTPS and read each listener's
status:

```sh
curl -s -o /dev/null -w "%{http_code}\n" --resolve bookstore.local:9443:127.0.0.1 \
  --cacert certs/ca.crt https://bookstore.local:9443/productpage
kubectl -n bookstore get gateway bookstore-gw -o jsonpath='{range .status.listeners[*]}{.name}: attachedRoutes={.attachedRoutes} {range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
```

```text
200
http: attachedRoutes=1 Accepted=True Conflicted=False Programmed=True ResolvedRefs=True
https: attachedRoutes=1 Accepted=True Conflicted=False Programmed=True ResolvedRefs=True
```

The page returns `200` over HTTPS, verified against the local CA. Both listeners report
`attachedRoutes=1`: an `HTTPRoute` without a `sectionName` in its `parentRefs` attaches to every
listener whose host name matches, so the same routes serve HTTP and HTTPS, as chapter 4's
`VirtualService` did. On the `https` listener, `ResolvedRefs=True` covers the certificate
reference too. Stop the port-forward with Ctrl+C.

## The Canary: Chapter 6 Again

Chapter 6 sent 90% of `reviews` traffic to v1 and 10% to v3, using subsets from a
`DestinationRule`. The Gateway API has no subsets. Each version is its own Service instead.
`14-gateway-api/reviews-versions.yaml` adds `reviews-v1` and `reviews-v3`, each selecting
`app: reviews` plus its `version` label. The original `reviews` Service stays, and callers keep
using it.

The route decides which of those Services gets each request.
`14-gateway-api/httproute-reviews-canary.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews
  namespace: bookstore
spec:
  parentRefs:
    - group: ""
      kind: Service
      name: reviews
      port: 9080
  rules:
    - backendRefs:
        - name: reviews-v1
          port: 9080
          weight: 90
        - name: reviews-v3
          port: 9080
          weight: 10
```

Its parent is a Service, not a Gateway. A route attached to a Service applies to mesh traffic sent
to that Service, which is the Gateway API's version of a `VirtualService` without `gateways`. The
pattern is called *GAMMA* (Gateway API for Mesh Management and Administration). As in chapter 6,
the decision is made in the caller's sidecar: `productpage` still calls `http://reviews:9080`, and
its sidecar picks `reviews-v1` or `reviews-v3`. The weights work as in chapter 6: each backend
gets its weight divided by the total.

Apply both files and count versions through each gateway, 100 requests through the new one and
20 through the old one:

```sh
kubectl apply -f 14-gateway-api/reviews-versions.yaml -f 14-gateway-api/httproute-reviews-canary.yaml
./scripts/count-versions.sh http://bookstore.local:9080 100
./scripts/count-versions.sh http://bookstore.local:8080 20
```

```text
service/reviews-v1 created
service/reviews-v3 created
httproute.gateway.networking.k8s.io/reviews created
  91 200 reviews-v1 no-stars fast
   9 200 reviews-v3 stars fast
  17 200 reviews-v1 no-stars fast
   3 200 reviews-v3 stars fast
```

The new gateway measured 91/9, close to the 90/10 asked for. The split also applies through the
old gateway on 8080 (17/3), because both gateways send requests to `productpage`, and its sidecar
makes the choice. `reviews-v2` no longer appears at all.

This worked cleanly because the `HTTPRoute` is the only route for `reviews`: no `VirtualService`
for `reviews` exists at this point in the series (chapter 6's reset removed its own). Don't define a `VirtualService` and an
`HTTPRoute` for the same host. Istio would have to merge two sources of routes, and I wouldn't
count on the result. (I didn't test that combination.) Move one host at a time.

## Break It: A Route Across Namespaces

Book Store's partner API from chapter 4 now belongs to a partners team, who want to keep their
routes in their own namespace, `partners`. The platform team adds a listener for them in
`14-gateway-api/gateway-partners.yaml`, which is `gateway.yaml` plus this listener on the same
port 80:

```yaml
    - name: api
      port: 80
      protocol: HTTP
      hostname: api.bookstore.local
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              kubernetes.io/metadata.name: partners
```

Only routes in the `partners` namespace may attach to the `api` listener.
(`kubernetes.io/metadata.name` is a label Kubernetes puts on every namespace, with its name as the
value.) Two things differ from chapter 4 on purpose. The partner listener is plain HTTP, without
chapter 4's client-certificate check, to keep the focus on namespaces. And the file has no HTTPS
listener, so applying it removes the `https` listener from the previous section, which nothing
below uses.

The partners team writes `14-gateway-api/partners-route.yaml`. The file also creates the
`partners` namespace; this is the route:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bookstore-api
  namespace: partners
spec:
  parentRefs:
    - name: bookstore-gw
      namespace: bookstore
      sectionName: api
  hostnames:
    - api.bookstore.local
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api/v1/products
      backendRefs:
        - name: productpage
          namespace: bookstore
          port: 9080
```

The parent is now in another namespace, so `parentRefs` names it with `namespace: bookstore`, and
`sectionName: api` attaches the route to that one listener. The backend, `productpage`, lives in
`bookstore` too. Apply both files and call the API, printing only the status code:

```sh
kubectl apply -f 14-gateway-api/gateway-partners.yaml -f 14-gateway-api/partners-route.yaml
curl -s -w " %{http_code}\n" -o /dev/null --resolve api.bookstore.local:9080:127.0.0.1 \
  http://api.bookstore.local:9080/api/v1/products
```

```text
configmap/bookstore-gw-options unchanged
gateway.gateway.networking.k8s.io/bookstore-gw configured
namespace/partners created
httproute.gateway.networking.k8s.io/bookstore-api created
 500
```

Kubernetes accepted every object, and the API answers `500`. Read the last line of the new
gateway's access log:

```sh
kubectl -n bookstore logs deploy/bookstore-gw-istio --tail=1
```

```text
[2026-11-17T02:27:23.422Z] "GET /api/v1/products HTTP/1.1" 500 NC cluster_not_found - "-" 0 0 0 - "172.21.0.4" "curl/8.7.1" "9c8a3d5a-0409-953e-aaf0-06d3ca9b43a5" "api.bookstore.local:9080" "-" - - 10.244.2.42:80 172.21.0.4:56167 - partners.bookstore-api.0
```

The flags are `NC cluster_not_found`, the same as chapter 5's mistyped destination: the route
matched (its name, `partners.bookstore-api.0`, is the last field), but it points at no cluster.
The status is `500` rather than chapter 5's `503`, because the Gateway API specification asks for
a `500` when a route's backend is invalid.

And `productpage` does exist. The route's status says why it wasn't used:

```sh
kubectl -n partners get httproute bookstore-api -o jsonpath='{range .status.parents[*]}{.parentRef.name}/{.parentRef.sectionName}{":\n"}{range .conditions[*]}  {.type}={.status} {.reason}: {.message}{"\n"}{end}{end}'
```

```text
bookstore-gw/api:
  Accepted=True Accepted: Route was valid
  ResolvedRefs=False RefNotPermitted: backendRef productpage/bookstore not accessible to a HTTPRoute in namespace "partners" (missing a ReferenceGrant?)
```

The listener accepted the route, so `allowedRoutes` worked. The backend didn't resolve:
`RefNotPermitted`. In the Gateway API, a `backendRef` to a Service in another namespace is valid
only if that namespace allows it. Otherwise any team could route traffic to any Service in the
cluster just by naming it. The permission is a `ReferenceGrant`, written by the team that owns the
target. The fix goes in `bookstore`, not in the route. `14-gateway-api/referencegrant.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: partners-to-bookstore
  namespace: bookstore
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: partners
  to:
    - group: ""
      kind: Service
```

Read it as "HTTPRoutes in `partners` may refer to Services in `bookstore`." `from` names the kind
and namespace of the objects that hold the reference, and `to` names the kind they may point at
(`group: ""` is the core API group, where Service lives). It lives in `bookstore` because the
bookstore team decides who may use their Services.

Apply it, read the route's conditions again, and call both paths on the partner host:

```sh
kubectl apply -f 14-gateway-api/referencegrant.yaml
kubectl -n partners get httproute bookstore-api -o jsonpath='{range .status.parents[*]}{range .conditions[*]}  {.type}={.status} {.reason}{"\n"}{end}{end}'
curl -s -w " %{http_code}\n" -o /dev/null --resolve api.bookstore.local:9080:127.0.0.1 \
  http://api.bookstore.local:9080/api/v1/products
curl -s -w " %{http_code}\n" -o /dev/null --resolve api.bookstore.local:9080:127.0.0.1 \
  http://api.bookstore.local:9080/productpage
```

```text
referencegrant.gateway.networking.k8s.io/partners-to-bookstore created
  Accepted=True Accepted
  ResolvedRefs=True ResolvedRefs
 200
 404
```

`ResolvedRefs` turned `True` without any change to the route. The API answers `200`, and
`/productpage` on the partner host gets `404`, because the partners' route covers only the API
path, as in chapter 4.

![Route attachment across namespaces: the HTTPRoute in namespace partners attaches through parentRefs to the api listener of the Gateway in bookstore, which allows routes from partners with allowedRoutes; its backendRef to the productpage Service in bookstore is permitted by a ReferenceGrant in bookstore; without the grant, ResolvedRefs is False with reason RefNotPermitted](/assets/images/posts/kubernetes-service-mesh-14-gateway-api/route-attachment.svg)

The figure shows the two permissions, owned by two teams. The Gateway owner decides who may
*attach* to a listener (`allowedRoutes`), and the backend owner decides who may *point at* their
Services (`ReferenceGrant`). Istio's API only covers part of this. An Istio `Gateway` host can
carry a namespace prefix, such as `partners/api.bookstore.local`, to limit which namespaces'
`VirtualService` objects may bind to it. But there is no object in which a Service's owner grants
access, and a `VirtualService` in any namespace can route to any Service it can see. For a cluster
shared by many teams, these two checks are one of the strongest reasons to use the Gateway API.

## What Still Needs Istio's API

The Gateway API covers routing well, but not every traffic feature from chapters 8 and 9. The quickest
way to see what a route rule can do is to ask the installed CRD. The standard `HTTPRoute` rule in
v1.6.1 has five fields:

```sh
kubectl explain httproute.spec.rules --api-version=gateway.networking.k8s.io/v1 | grep -E "^  [a-z]"
```

```text
  backendRefs	<[]Object>
  filters	<[]Object>
  matches	<[]Object>
  name	<string>
  timeouts	<Object>
```

Timeouts are there; retries and fault injection (chapter 8) aren't, at least not in the standard
channel. The Gateway API also publishes an experimental channel, a separate set of CRDs with
fields that can still change. Check Istio's documentation for which experimental fields it
supports before you depend on one. Until then, a host that needs retries or fault injection
stays on a `VirtualService`, since mixing a `VirtualService` and an `HTTPRoute` for one host is
what the canary section warned against.

Traffic policy is the other gap, and Istio fills it by letting its own objects work alongside the
Gateway API. A `DestinationRule` still applies to traffic that a Gateway API gateway sends. To
check, apply `14-gateway-api/destinationrule-productpage.yaml`, an outlier-detection policy for
`productpage` like chapter 9's, and look at the new gateway's cluster for `productpage`:

```sh
kubectl apply -f 14-gateway-api/destinationrule-productpage.yaml
istioctl proxy-config cluster deploy/bookstore-gw-istio -n bookstore --fqdn productpage.bookstore.svc.cluster.local
```

```text
destinationrule.networking.istio.io/productpage created
SERVICE FQDN                                PORT     SUBSET     DIRECTION     TYPE     DESTINATION RULE
productpage.bookstore.svc.cluster.local     9080     -          outbound      EDS      productpage.bookstore
```

The `DESTINATION RULE` column names `productpage.bookstore`: the gateway's Envoy applies the
policy. So chapter 9's outlier detection and connection pools carry over unchanged.

Security policy isn't routing at all, so it doesn't move either. `PeerAuthentication` and
`AuthorizationPolicy` from chapters 11 and 12 stay as they are. `STRICT` mutual TLS from chapter
11 has been on in `bookstore` for this whole chapter, and every request through the new gateway
passed it. One adjustment if you keep chapter 12's policies: its `productpage` policy allows only
the `istio-ingressgateway-service-account` identity. The new gateway runs as its own service
account, `bookstore-gw-istio`, so you would add the principal
`cluster.local/ns/bookstore/sa/bookstore-gw-istio` to that policy.

![Mapping table as a figure: Istio Gateway servers map to Gateway API Gateway listeners; a VirtualService bound to a gateway maps to an HTTPRoute with a Gateway parentRef; a VirtualService for mesh traffic maps to an HTTPRoute with a Service parentRef; DestinationRule subsets with route weights map to one Service per version with weighted backendRefs; credentialName with the Secret in the gateway Pods' namespace, istio-system, maps to certificateRefs with the Secret in the Gateway's namespace, bookstore; retries and fault injection have no standard field and stay on a VirtualService, and DestinationRule traffic policy stays in a DestinationRule](/assets/images/posts/kubernetes-service-mesh-14-gateway-api/api-mapping.svg)

The figure sums up the move from chapters 3 to 6. The table below lists the same mapping field by
field, and you can use it as a checklist when you translate your own routes:

| Istio API (chapters 3-6) | Gateway API |
| --- | --- |
| `Gateway` (configures `istio-ingressgateway`) | `Gateway` with `gatewayClassName: istio` (creates its own proxy) |
| `servers` with port, protocol, hosts | `listeners` with port, protocol, hostname |
| `VirtualService` with `gateways:` | `HTTPRoute` with a Gateway in `parentRefs` |
| `VirtualService` for mesh traffic | `HTTPRoute` with a Service in `parentRefs` (GAMMA) |
| `DestinationRule` subsets + route weights | One Service per version + weighted `backendRefs` |
| `tls.mode: SIMPLE` + `credentialName` (Secret in the gateway Pods' namespace) | `tls.mode: Terminate` + `certificateRefs` (Secret in the `Gateway` object's namespace) |
| `redirect` | `RequestRedirect` filter |
| `timeout` | `timeouts.request` |
| `retries`, `fault` | Not in the standard channel; keep that host on a `VirtualService` |
| `DestinationRule` traffic policy | Keep `DestinationRule`; it still applies |
| `Gateway` hosts with a `namespace/` prefix; no grant for destinations | `allowedRoutes` + `ReferenceGrant` across namespaces |

## Reset Before the Next Chapter

Remove the Gateway API objects. `gateway-https.yaml` holds the whole `Gateway`, so deleting it
removes `bookstore-gw`, and Istio removes the Deployment and Service it created for it. Deleting
`partners-route.yaml` also deletes the `partners` namespace. `--ignore-not-found` on the second
command covers the case where you skipped the partners section. Keep the CRDs; they're harmless:

```sh
kubectl delete -f 14-gateway-api/httproute-reviews-canary.yaml -f 14-gateway-api/reviews-versions.yaml \
  -f 14-gateway-api/httproute.yaml -f 14-gateway-api/gateway-https.yaml \
  -f 14-gateway-api/destinationrule-productpage.yaml
kubectl delete -f 14-gateway-api/partners-route.yaml -f 14-gateway-api/referencegrant.yaml --ignore-not-found
kubectl -n bookstore delete configmap bookstore-gw-options
kubectl -n bookstore delete secret bookstore-local-tls
```

```text
httproute.gateway.networking.k8s.io "reviews" deleted
service "reviews-v1" deleted
service "reviews-v3" deleted
httproute.gateway.networking.k8s.io "bookstore" deleted
gateway.gateway.networking.k8s.io "bookstore-gw" deleted
destinationrule.networking.istio.io "productpage" deleted
...
```

Chapter 15 starts over on a new cluster, so you can also delete this one now:
`kind delete cluster --name mesh`.

## Summary

- The Gateway API is the Kubernetes standard for routing. Install its CRDs (v1.6.1 here) and Istio
  registers the `istio` GatewayClass.
- A Gateway API `Gateway` creates its own Deployment and Service (`<name>-istio`); on Kind, a
  ConfigMap in `infrastructure.parametersRef` makes the Service a fixed NodePort.
- An `HTTPRoute` attaches to a Gateway (edge traffic) or to a Service (mesh traffic, GAMMA).
  Weighted `backendRefs` to per-version Services replace subsets.
- Read `status.parents` on routes and `status.listeners` on Gateways. A cross-namespace backend
  needs a `ReferenceGrant` in the target namespace, or `ResolvedRefs` is `False`
  (`RefNotPermitted`).
- Retries, fault injection, and `DestinationRule` traffic policies still use Istio's API, and
  security policies don't change. Next, chapter 15 installs Istio the way you would in your own
  environment, with Helm and revisions.
