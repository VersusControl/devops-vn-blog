---
layout: post
title: "Timeouts, Retries, and Fault Injection with Istio"
series: "Kubernetes Advanced: Service Mesh"
series_url: /kubernetes-service-mesh-series/
part: 8
date: 2026-10-26
author: Quan Huynh
subtitle: "Find out why a page fails when every timeout looks generous, fix it with mesh timeouts and retries, and test failure on purpose for one user with fault injection."
tags: [kubernetes, istio, service-mesh, resilience, fault-injection]
image: /assets/images/posts/kubernetes-service-mesh-08-timeouts-retries-fault-injection/cover.svg
---

A slow dependency does more damage than a dead one. A dead service fails fast and callers move
on. A slow one holds every caller's request open, and the callers' callers wait too. Chapter 1
found three timeouts hard-coded in Book Store: `productpage` waits 3 seconds for `reviews` and
tries twice, `reviews` v2 waits 10 seconds for `ratings`, and `reviews` v3 waits 2.5 seconds.
Each looks reasonable on its own. This chapter puts them in front of a slow `ratings` build, and
the result is a failure that none of the three numbers predicts.

Then it fixes the problem without changing any application code. Istio can set a timeout and a
retry policy on any call between services with a few lines of YAML, and the change takes effect
without a release. And because waiting for a real outage is a poor way to test, Istio can also
inject faults: delays and errors added by the sidecar, scoped to one user if you want.

By the end of this chapter you will:

- Explain why nested timeouts make a page fail even when the slow call would have succeeded.
- Read the failure and its fix in the access logs, with the `DC`, `UT`, and `URX` response flags.
- Set a `timeout` on a route, and combine it with `retries` and `perTryTimeout`.
- Inject a delay or an error for one user only, and know one limit of testing timeouts this way.

> **Code for this chapter.** The files are in
> [_resource/kubernetes-service-mesh/08-resilience](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/kubernetes-service-mesh/08-resilience).
> I tested them with Kind v0.33.0 (Kubernetes v1.37.0) and Istio 1.32.0 on macOS with Docker
> Desktop, and the command output in this chapter comes from those runs.

## Starting Point

Run every command from `_resource/kubernetes-service-mesh`:

```sh
export PATH="$PWD/bin:$PATH"
```

The chapter needs Book Store at `http://bookstore.local:8080`, the `reviews` `DestinationRule`
from chapter 6, and no `VirtualService` for `reviews`. Chapter 7's reset left the cluster in that
state. To build it from scratch:

```sh
./scripts/bootstrap.sh 08
```

## Set Up the Slow Build

The scenario is chapter 1's slow `ratings` build. In chapter 1, connection picks decided who
reached it; here a `VirtualService` sends every `ratings` call to it on purpose. Four files set it
up:

- `ratings-v-delayed.yaml`: a second `ratings` Deployment, same image, with
  `SERVICE_VERSION=v-delayed`. Half of its answers take 7 seconds.
- `destinationrule-ratings.yaml`: subsets `v1` and `v-delayed` for `ratings`.
- `virtualservice-reviews-v2.yaml`: all `reviews` traffic to v2, the version that waits up to
  10 seconds for `ratings`. One version keeps the results readable.
- `virtualservice-ratings-delayed.yaml`: all `ratings` traffic to `v-delayed`. No timeout, no
  retries.

```sh
kubectl apply -f 08-resilience/ratings-v-delayed.yaml -f 08-resilience/destinationrule-ratings.yaml
kubectl -n bookstore rollout status deploy/ratings-v-delayed
kubectl apply -f 08-resilience/virtualservice-reviews-v2.yaml \
  -f 08-resilience/virtualservice-ratings-delayed.yaml
```

```text
deployment.apps/ratings-v-delayed created
destinationrule.networking.istio.io/ratings created
Waiting for deployment "ratings-v-delayed" rollout to finish: 0 of 1 updated replicas are available...
deployment "ratings-v-delayed" successfully rolled out
virtualservice.networking.istio.io/reviews created
virtualservice.networking.istio.io/ratings created
```

The `DestinationRule` goes in before the `VirtualService` that uses its subsets, as chapter 6
taught.

## The Failure: Every Timeout Looks Generous

Look at the call to `ratings` on its own first. `ratings` answers in 7 seconds at worst.
`reviews` v2 waits 10 seconds for it, so `reviews` always gets its stars. Judged by that one
call, the page should be slow half the time and never broken. Send 20 requests:

```sh
./scripts/count-versions.sh http://bookstore.local:8080 20
```

```text
   7 200 reviews-v2 stars fast
   7 200 reviews-v2 stars 3-8s
   6 500 reviews-none - 3-8s
```

Six of 20 requests failed with `500`, and seven more were slow. The run took about a minute.
Nothing in `ratings` failed. To find out why, start at the top of the chain, with
`productpage`'s calls to `reviews` in its sidecar's access log:

```sh
kubectl -n bookstore logs deploy/productpage-v1 -c istio-proxy --since=90s | grep 'reviews:9080' | tail -4
```

```text
[2026-11-17T01:40:50.195Z] "GET /reviews/0 HTTP/1.1" 200 - via_upstream - "-" 0 442 14 14 "-" "curl/8.7.1" "743980f3-14e8-45ce-9aa7-30e27cce4225" "reviews:9080" "10.244.2.11:9080" outbound|9080|v2|reviews.bookstore.svc.cluster.local 10.244.2.16:54966 10.96.121.127:9080 10.244.2.16:56312 - -
[2026-11-17T01:40:50.253Z] "GET /reviews/0 HTTP/1.1" 0 DC downstream_remote_disconnect - "-" 0 0 3006 - "-" "curl/8.7.1" "67e81bd5-74ca-4fd2-a0f3-0ee8f2be154a" "reviews:9080" "10.244.2.11:9080" outbound|9080|v2|reviews.bookstore.svc.cluster.local 10.244.2.16:54966 10.96.121.127:9080 10.244.2.16:56324 - -
[2026-11-17T01:40:53.266Z] "GET /reviews/0 HTTP/1.1" 0 DC downstream_remote_disconnect - "-" 0 0 3001 - "-" "curl/8.7.1" "67e81bd5-74ca-4fd2-a0f3-0ee8f2be154a" "reviews:9080" "10.244.2.11:9080" outbound|9080|v2|reviews.bookstore.svc.cluster.local 10.244.2.16:39476 10.96.121.127:9080 10.244.2.16:56334 - -
[2026-11-17T01:40:56.322Z] "GET /reviews/0 HTTP/1.1" 200 - via_upstream - "-" 0 442 15 14 "-" "curl/8.7.1" "07796a54-5413-4c79-86d8-a632e83b4ac0" "reviews:9080" "10.244.2.11:9080" outbound|9080|v2|reviews.bookstore.svc.cluster.local 10.244.2.16:54978 10.96.121.127:9080 10.244.2.16:56348 - -
```

Chapter 5 maps every field of this log format. The first and last lines are normal: `200` in
14 and 15 milliseconds. The middle two lines are one user request (same request ID,
`67e81bd5...`). Each has status `0` and the flag `DC`, *downstream connection termination*: the
caller hung up before an answer came. The duration says when: 3006 and 3001 milliseconds. That's
`productpage`'s 3-second timeout in its Python code, then its one retry, also cut at 3 seconds.
After two failures, `productpage` returned `500` to the user.

Now the same request ID one hop down, in `reviews` v2's sidecar:

```sh
kubectl -n bookstore logs deploy/reviews-v2 -c istio-proxy --since=90s | grep 67e81bd5 | grep 'ratings:9080'
```

```text
[2026-11-17T01:40:50.257Z] "GET /ratings/0 HTTP/1.1" 200 - via_upstream - "-" 0 48 7005 7005 "-" "curl/8.7.1" "67e81bd5-74ca-4fd2-a0f3-0ee8f2be154a" "ratings:9080" "10.244.2.20:9080" outbound|9080|v-delayed|ratings.bookstore.svc.cluster.local 10.244.2.11:51874 10.96.254.132:9080 10.244.2.11:59848 - -
[2026-11-17T01:40:53.275Z] "GET /ratings/0 HTTP/1.1" 200 - via_upstream - "-" 0 48 7007 7006 "-" "curl/8.7.1" "67e81bd5-74ca-4fd2-a0f3-0ee8f2be154a" "ratings:9080" "10.244.2.20:9080" outbound|9080|v-delayed|ratings.bookstore.svc.cluster.local 10.244.2.11:51862 10.96.254.132:9080 10.244.2.11:59842 - -
```

Both calls to `ratings` succeeded, with `200`, after 7 seconds each. `reviews` waited
patiently, as its 10-second timeout allowed, and finished its work 4 seconds after `productpage`
had stopped listening. The work was wasted, and the second attempt doubled it.

The timeline puts the two logs together:

![Nested timeouts on a timeline: productpage's first call to reviews is cut at 3 seconds and its retry is cut at 6 seconds, so the user gets a 500; underneath, reviews v2 waits 7 seconds for each slow ratings answer, well inside its own 10-second limit, and both ratings calls finish successfully after productpage has already given up](/assets/images/posts/kubernetes-service-mesh-08-timeouts-retries-fault-injection/nested-timeouts.svg)

The rule this breaks: a caller's timeout must be longer than the total time its callee may take,
including the callee's own waits and retries. Here the caller allows 3 seconds and the callee
allows itself 10. The successful slow requests (`200 ... 3-8s`) are the lucky ones: the first
attempt timed out and the retry happened to hit a fast `ratings` answer.

## Fix It with a Mesh Timeout

The three timeouts live in two languages and need code changes to move. A mesh timeout doesn't.
Set one on the call that's slow, `reviews` → `ratings`, short enough to fit inside
`productpage`'s 3 seconds. `08-resilience/virtualservice-ratings-timeout.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ratings
  namespace: bookstore
spec:
  hosts:
    - ratings
  http:
    - route:
        - destination:
            host: ratings
            subset: v-delayed
      timeout: 2s
```

`timeout: 2s` makes `reviews`' sidecar give up on `ratings` after 2 seconds and answer
`reviews` with `504 Gateway Timeout`. The `reviews` app handles a failed `ratings` call the way
chapter 1 showed: it returns the reviews with "Ratings service is currently unavailable" in place
of the stars. Two seconds leaves about a second of `productpage`'s 3 for `reviews`' own work and
the network. Istio's default for HTTP routes is no timeout at all, which is why `reviews` waited
7 seconds before.

```sh
kubectl apply -f 08-resilience/virtualservice-ratings-timeout.yaml
./scripts/count-versions.sh http://bookstore.local:8080 20
```

```text
virtualservice.networking.istio.io/ratings configured
  11 200 reviews-v2 ratings-error 1-3s
   9 200 reviews-v2 stars fast
```

No more `500`s and no more 3-to-8-second waits. Every page loads; about half show the ratings
error instead of stars, after 2 seconds. That's *graceful degradation*: one part of the page is
missing, and the rest works. `reviews`' sidecar shows the timeout:

```sh
kubectl -n bookstore logs deploy/reviews-v2 -c istio-proxy --since=60s | grep 'ratings:9080' | grep -v ' 200 ' | tail -1
```

```text
[2026-11-17T01:41:37.299Z] "GET /ratings/0 HTTP/1.1" 504 UT response_timeout - "-" 0 24 2002 - "-" "curl/8.7.1" "0215a967-74b8-4a8a-b13d-ddd9bdc3dbaf" "ratings:9080" "10.244.2.20:9080" outbound|9080|v-delayed|ratings.bookstore.svc.cluster.local 10.244.2.11:48336 10.96.254.132:9080 10.244.2.11:54842 - -
```

`504 UT response_timeout` after 2002 ms. `UT`, *upstream request timeout*, is the flag Envoy sets
when a route's timeout fires.

## Add Retries with a Per-Try Timeout

The timeout stopped the `500`s, but half the pages still lose their stars. Half of the slow
build's answers are fast, though. So instead of waiting up to 2 seconds for one attempt, cut each
attempt short and try again; the next attempt has an even chance of a fast answer.
`08-resilience/virtualservice-ratings-retries.yaml` keeps the same `VirtualService` and adds a
`retries` block to its one rule (the rest of the file is unchanged):

```yaml
    - route:
        - destination:
            host: ratings
            subset: v-delayed
      timeout: 2s
      retries:
        attempts: 2
        perTryTimeout: 500ms
        retryOn: 5xx,reset,connect-failure
```

- `attempts: 2` allows two retries after the first attempt, three tries in total.
- `perTryTimeout: 500ms` limits each attempt. A healthy `ratings` answers in a few milliseconds,
  so half a second is plenty.
- `retryOn` lists the failures worth retrying: any `5xx` response, a reset connection, or a
  failed connect. An attempt cut by `perTryTimeout` counts as a failure under `5xx`, which is
  what makes the slow answers retryable here.
- `timeout: 2s` still caps the whole call, all attempts and the short pauses between them
  included. Three attempts of 500 ms fit inside it with room for the pauses.

The timeline shows how the limits nest:

![Retries over time: the overall 2-second timeout as an outer bar; inside it, three attempts each limited to 500 milliseconds by perTryTimeout with a short pause between them; the first two slow attempts are cut at 500 milliseconds and the third gets a fast answer](/assets/images/posts/kubernetes-service-mesh-08-timeouts-retries-fault-injection/retries-timeline.svg)

```sh
kubectl apply -f 08-resilience/virtualservice-ratings-retries.yaml
./scripts/count-versions.sh http://bookstore.local:8080 40
```

```text
virtualservice.networking.istio.io/ratings configured
  31 200 reviews-v2 stars fast
   5 200 reviews-v2 stars 1-3s
   4 200 reviews-v2 ratings-error 1-3s
```

36 of 40 pages now show stars, from a dependency that is slow half the time. Three tries that
each succeed half the time all fail with a chance of 1 in 8, about 5 requests in 40; four failed
here. A success on the second try costs one cut attempt, about half a second, so it still lands
in `fast`. The five `1-3s` successes needed the third try. The failed ones are in the log with
two flags:

```sh
kubectl -n bookstore logs deploy/reviews-v2 -c istio-proxy --since=90s | grep 'ratings:9080' | grep 'URX' | tail -1
```

```text
[2026-11-17T01:42:01.603Z] "GET /ratings/0 HTTP/1.1" 504 URX,UT upstream_per_try_timeout - "-" 0 24 1552 - "-" "curl/8.7.1" "3fd4e891-eb01-48ef-9da8-ca44af823594" "ratings:9080" "10.244.2.20:9080" outbound|9080|v-delayed|ratings.bookstore.svc.cluster.local 10.244.2.11:36550 10.96.254.132:9080 10.244.2.11:54826 - -
```

`UT` with `upstream_per_try_timeout`: the attempts were cut by `perTryTimeout`. `URX`: the
retries ran out. The duration, 1552 ms, is three attempts of 500 ms plus the pauses.

Retries have a cost. Every retry is another request to a service that may already be struggling,
so a retry policy can turn a slowdown into an overload. Retries also multiply across layers:
`productpage` already tries `reviews` twice in its code, so if both layers retried the same
failure, one page load could send six requests to `ratings`. Keep `attempts` low, always set a
`perTryTimeout` and an overall `timeout`, and retry only calls that are safe to repeat (a `GET`,
or a write that the server deduplicates). Chapter 9 adds the other half of the protection:
limits on how much traffic a struggling service receives.

## Test Failure on Purpose: Fault Injection

A real slow build is a poor test tool. You can't schedule it, and you can't aim it at one tester.
*Fault injection* lets the sidecar create the failure instead: a delay before forwarding a
request, or an error instead of forwarding it. Scoped with a `match`, it affects only test
traffic, so you can run it in a shared environment or even in production, as long as ordinary
users can't send the header it matches (chapter 7's warning about the sign-in applies here too).

Move `ratings` back to the healthy v1, and add a 7-second delay for the QA user only. The
`reviews` `VirtualService` from the setup stays, so every request still goes to v2.
`08-resilience/virtualservice-ratings-fault.yaml`:

```yaml
  http:
    - name: qa-team-delay
      match:
        - headers:
            end-user:
              exact: qa-team
      fault:
        delay:
          percentage:
            value: 100
          fixedDelay: 7s
      route:
        - destination:
            host: ratings
            subset: v1
    - name: default
      route:
        - destination:
            host: ratings
            subset: v1
```

The `qa-team-delay` rule holds 100% of matching requests for a fixed 7 seconds, then routes them
normally. The `default` rule, last and without a match, serves everyone else. The match works on
`ratings` calls because `reviews` forwards the `end-user` header it receives from `productpage`,
the header propagation from chapter 7.

Sign in as `qa-team` again (chapter 7's reset deleted the cookie file) and compare an anonymous
user with QA. The QA run takes over half a minute, 6 seconds per request:

```sh
curl -s --resolve bookstore.local:8080:127.0.0.1 -c /tmp/qa-cookies.txt \
  -d 'username=qa-team&passwd=anything' -o /dev/null http://bookstore.local:8080/login
kubectl apply -f 08-resilience/virtualservice-ratings-fault.yaml
./scripts/count-versions.sh http://bookstore.local:8080 10
CURL_OPTS="-b /tmp/qa-cookies.txt" ./scripts/count-versions.sh http://bookstore.local:8080 6
```

```text
virtualservice.networking.istio.io/ratings configured
  10 200 reviews-v2 stars fast
   6 500 reviews-none - 3-8s
```

The anonymous requests are fast and show stars. QA reproduces the nested-timeout failure every
time, on demand, with a healthy `ratings`. The log line in `reviews`' sidecar names the fault:

```sh
kubectl -n bookstore logs deploy/reviews-v2 -c istio-proxy --since=60s | grep ' DI ' | tail -1
```

```text
[2026-11-17T01:42:56.113Z] "GET /ratings/0 HTTP/1.1" 200 DI via_upstream - "-" 0 48 7005 2 "-" "curl/8.7.1" "62caf327-af39-44a2-9c1f-67bead2e5544" "ratings:9080" "10.244.2.10:9080" outbound|9080|v1|ratings.bookstore.svc.cluster.local 10.244.2.11:57046 10.96.254.132:9080 10.244.2.11:44134 - qa-team-delay
```

`DI` means *delay injected*. The total duration is 7005 ms, while `ratings` itself took 2 ms (the
upstream time). The last field is the rule name, `qa-team-delay`.

The fault happens in the caller's sidecar, not in `ratings`. The figure shows both kinds of fault
this chapter uses, the delay and the error from the next section:

![Fault injection happens in the caller's sidecar: for a request with end-user qa-team, reviews v2's Envoy holds the request for 7 seconds before forwarding it to ratings v1, or answers 503 itself without calling ratings; requests from other users pass straight through to ratings v1](/assets/images/posts/kubernetes-service-mesh-08-timeouts-retries-fault-injection/fault-injection.svg)

### Inject errors instead of delays

An `abort` fault answers with an error without calling the service at all. It tests the other
failure path: what the caller does with an error, rather than with a slow answer.
`08-resilience/virtualservice-ratings-abort.yaml` has the same two rules, with the QA rule renamed
`qa-team-abort` and its `fault` block replaced. It fails half of QA's `ratings` calls with `503`:

```yaml
      fault:
        abort:
          percentage:
            value: 50
          httpStatus: 503
```

```sh
kubectl apply -f 08-resilience/virtualservice-ratings-abort.yaml
./scripts/count-versions.sh http://bookstore.local:8080 10
CURL_OPTS="-b /tmp/qa-cookies.txt" ./scripts/count-versions.sh http://bookstore.local:8080 20
kubectl -n bookstore logs deploy/reviews-v2 -c istio-proxy --since=60s | grep ' FI ' | tail -1
```

```text
virtualservice.networking.istio.io/ratings configured
  10 200 reviews-v2 stars fast
  12 200 reviews-v2 stars fast
   8 200 reviews-v2 ratings-error fast
[2026-11-17T01:43:16.866Z] "GET /ratings/0 HTTP/1.1" 503 FI fault_filter_abort - "-" 0 18 0 - "-" "curl/8.7.1" "3d1436b6-513e-401c-b2e6-bc852f76c16f" "ratings:9080" "-" outbound|9080|v1|ratings.bookstore.svc.cluster.local - 10.96.254.132:9080 10.244.2.11:36508 - qa-team-abort
```

The first count line is the anonymous run, all stars; the next two are QA's. 8 of QA's 20
requests showed the ratings error, close to half, and `reviews` handled each one the same way as
the timeout: `200`, with the error in place of the stars. In the log line, `FI` means *fault
injected*, and the upstream host is `"-"`: the request never left the sidecar.

### One limit: a timeout doesn't cover an injected delay

The obvious way to test this chapter's 2-second timeout is to put a `fault.delay` and a
`timeout` on the same route. It doesn't work. I added `timeout: 2s` to the `qa-team-delay` rule
and sent QA requests: the call to `ratings` still took 7003 ms and returned `200`, and QA still
got the `500`. The timeout never fired, even 5 seconds past its limit. It wasn't missing from the
configuration: `istioctl proxy-config route deploy/reviews-v2 -n bookstore --name 9080 -o json`
showed `"timeout": "2s"` on the `qa-team-delay` route, next to the fault. Inside Envoy, the fault
filter runs before the router, and the router starts the timeout clock only when the request
reaches it, after the delay is over. So a test built this way tells you nothing about the
timeout.

To test a timeout with fault injection, put the delay on the next hop down, as Istio's own
examples do: delay `ratings`, and set the timeout on the route to `reviews`. The timeout on
`ratings` itself has no hop below it in Book Store, so it needs a real slow build, as this chapter
used first.

## Reset Before the Next Chapter

Delete this chapter's routing objects, the `ratings` subsets, and the slow build. Keep the
`reviews` `DestinationRule`:

```sh
kubectl delete virtualservice ratings reviews -n bookstore
kubectl delete -f 08-resilience/destinationrule-ratings.yaml -f 08-resilience/ratings-v-delayed.yaml
rm -f /tmp/qa-cookies.txt
```

```text
virtualservice.networking.istio.io "ratings" deleted
virtualservice.networking.istio.io "reviews" deleted
destinationrule.networking.istio.io "ratings" deleted
deployment.apps "ratings-v-delayed" deleted
```

To rebuild the starting state of chapter 9 from scratch: `./scripts/bootstrap.sh 09`.

## Summary

- Timeouts must shrink down the call chain. `productpage` waited 3 seconds (twice) for a
  `reviews` that would wait 10 for `ratings`, so a 7-second `ratings` answer turned into a `500`
  even though every call to `ratings` succeeded. The logs show it as `DC` at the caller and slow
  `200`s below.
- A `VirtualService` `timeout` sets a limit on any call from YAML (`UT` in the log). Istio's
  default HTTP route has none.
- `retries` with `perTryTimeout` replace slow attempts with new ones; the overall `timeout` caps
  them all (`URX` when they run out). Keep attempts low, and retry only safe requests.
- `fault.delay` (`DI`) and `fault.abort` (`FI`) inject failures in the caller's sidecar, and a
  `match` limits them to test traffic. A route's `timeout` doesn't cover its own injected delay.
- Next, chapter 9 protects a struggling service with connection limits and removes a failing Pod
  from the load balancer with outlier detection.
