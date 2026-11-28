---
layout: post
title: "Why DNS Lookups Are Slow in Kubernetes, and How to Fix Them"
subtitle: "Why one lookup of an external name from a Pod can cost CoreDNS eight queries instead of two, and how a trailing dot, a lower ndots, or NodeLocal DNSCache cuts that down."
date: 2026-11-27
author: Quan Huynh
tags: [kubernetes, dns, coredns, eks, performance]
image: /assets/images/posts/kubernetes-reduce-dns-resolution-time/cover.svg
---

Say your application looks up `api.github.com` a few hundred times a second. On a laptop that
costs almost nothing. Inside Kubernetes, each of those lookups can turn into eight DNS queries,
and six of them are expected to fail before the right one succeeds. With enough Pods, CoreDNS
(the DNS server that runs inside the cluster) can't keep up, and DNS errors start to look like
random network failures.

This happened to OLX Autos on Amazon EKS. As they scaled toward 10,000 Pods, CoreDNS started
crashing and their application latency peaked at around 3000 ms. Two fixes from this post, a trailing dot and a
node-level DNS cache, brought it back under 50 ms ([AWS blog](https://aws.amazon.com/blogs/containers/scale-from-100-to-10000-pods-on-amazon-eks/)).

This post explains why one lookup from a Pod becomes several DNS queries, shows how to count
those queries on a test cluster, and compares three fixes: a trailing dot, a lower `ndots`, and
NodeLocal DNSCache.

> **Code for this post:** [_resource/kubernetes-dns-ndots](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/kubernetes-dns-ndots).
> I ran every test on Kind with Kubernetes 1.37 and the default CoreDNS, and the outputs below
> come from that run. EKS uses the same defaults for Pod DNS.

## How a Pod Looks Up a Name

When code in a Pod connects to a host name, a small piece of the C library called the *resolver*
turns that name into an IP address. (The test Pods in this post use glibc, like most application
images.) The resolver reads its settings from a file, `/etc/resolv.conf`. Kubernetes writes this
file into every Pod. This is the file in a default Pod in the `default` namespace:

```text
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

Each line does one job:

- `nameserver` is the IP address the resolver sends queries to. In a cluster, this is the
  cluster DNS Service, which CoreDNS answers.
- `search` is the *search list*: suffixes the resolver adds to a name before it asks. It lets
  your code call a Service by a short name, so `orders` becomes `orders.default.svc.cluster.local`.
- `ndots:5` decides when the search list is used. If a name has fewer than 5 dots, the resolver
  tries every search suffix first and the name as written only at the end.

`api.github.com` has two dots. Two is fewer than five, so the resolver treats it as a possible
short name. It tries all three suffixes before it asks for `api.github.com` itself.

![With ndots:5, a Pod's lookup of api.github.com tries three search suffixes first: api.github.com.default.svc.cluster.local, api.github.com.svc.cluster.local and api.github.com.cluster.local, each an A and an AAAA query that returns NXDOMAIN, for 6 wasted queries. Only the fourth attempt, api.github.com., gets an answer, in 2 queries.](/assets/images/posts/kubernetes-reduce-dns-resolution-time/search-list-fanout.svg)

## See It Happen

CoreDNS doesn't log queries by default, so the first step is to turn on its `log` plugin. Do
this on a test cluster only. Then start two Pods that are identical except for one DNS option:
`app-default` keeps `ndots:5`, and `app-ndots2` sets `ndots:2` (used in Fix 2).

```sh
cd _resource/kubernetes-dns-ndots
./enable-coredns-log.sh
kubectl apply -f pods.yaml
kubectl wait --for=condition=Ready pod/app-default pod/app-ndots2
```

The `count-queries.sh` script resolves one name from a Pod and prints the queries CoreDNS
received for it, one per line: record type, full name asked for, and result. Start with the
default Pod and `amazon.com`. It has one dot, so it goes through the search list the same way
`api.github.com` does:

```sh
./count-queries.sh app-default amazon.com
```

```text
A amazon.com.default.svc.cluster.local. NXDOMAIN
AAAA amazon.com.default.svc.cluster.local. NXDOMAIN
AAAA amazon.com.svc.cluster.local. NXDOMAIN
A amazon.com.svc.cluster.local. NXDOMAIN
AAAA amazon.com.cluster.local. NXDOMAIN
A amazon.com.cluster.local. NXDOMAIN
A amazon.com. NOERROR
AAAA amazon.com. NOERROR
```

A single lookup produced eight queries. For each attempt, the resolver asks for both an IPv4
address (an `A` record) and an IPv6 address (an `AAAA` record), so every wasted suffix costs two
queries. Six of the eight end in `NXDOMAIN`, which means "this name doesn't exist". Only the last
two return a real answer (`NOERROR`).

Your application never sees these extra queries. It only sees a lookup that takes longer than it
should and, under load, sometimes fails.

## Fix 1: Add a Trailing Dot

A name that ends with a dot, such as `amazon.com.`, is a *fully qualified domain name* (FQDN).
The dot tells the resolver the name is already complete, so it skips the search list. Run the
same test on the same Pod, with a dot added to the name:

```sh
./count-queries.sh app-default amazon.com.
```

```text
A amazon.com. NOERROR
AAAA amazon.com. NOERROR
```

The resolver went straight to `amazon.com.`, so eight queries became two. To measure the time
saved, the `bench.py` script resolves a name 300 times inside the Pod and prints the average
time per lookup:

```sh
kubectl cp bench.py app-default:/tmp/bench.py
kubectl exec app-default -- python /tmp/bench.py api.github.com
kubectl exec app-default -- python /tmp/bench.py api.github.com.
```

```text
api.github.com     300 lookups: 0.58 ms avg
api.github.com.    300 lookups: 0.14 ms avg
```

On an idle test cluster, the trailing dot made lookups about four times faster. On a busy
cluster, the bigger win is the load you take off CoreDNS: OLX Autos cut more than 70% of the
queries their CoreDNS servers received this way.

There's a catch. The dot doesn't stay in DNS: it goes wherever the host name goes, including the
HTTP `Host` header and the name your client checks against the server's TLS certificate. I sent
real HTTPS requests from my laptop with the dot added:

| Request | Result |
| --- | --- |
| `curl https://aws.amazon.com./` | 200 |
| `curl https://www.google.com./` | 301 (a normal redirect) |
| `curl https://api.github.com./` | 400 Bad Request |
| Python `urllib` to `https://api.github.com./` | `CERTIFICATE_VERIFY_FAILED`: hostname mismatch |

So the dot is safe where only the lookup sees the name, and risky in HTTPS URLs. Test each
client and endpoint before you add it. For HTTPS APIs, Fix 2 is usually the safer choice.

## Fix 2: Lower `ndots` for the Pod

A trailing dot means changing every external name in your configuration. If that isn't
practical, change the rule instead. The `dnsConfig` field in the Pod spec adds options to the
Pod's `/etc/resolv.conf`, and an `ndots` option there replaces the default of 5:

```yaml
spec:
  dnsConfig:
    options:
    - name: ndots
      value: "2"
```

With `ndots:2`, any name with two or more dots is tried as written first:

```sh
./count-queries.sh app-ndots2 api.github.com
```

```text
A api.github.com. NOERROR
AAAA api.github.com. NOERROR
```

The query count drops to two, and the application code doesn't change. Short Service names
still work, because they have fewer than two dots and still go through the search list. These
were the results from the `app-ndots2` Pod:

| Name | Dots | Queries | Resolved |
| --- | --- | --- | --- |
| `api.github.com` | 2 | 2 | yes |
| `kubernetes` | 0 | 2 | yes, as `kubernetes.default.svc.cluster.local` |
| `kubernetes.default` | 1 | 4 | yes |

The last row costs four queries because the resolver first tries
`kubernetes.default.default.svc.cluster.local`, which doesn't exist, and then
`kubernetes.default.svc.cluster.local`, which does.

`ndots:2` has two costs. First, it doesn't help a name with one dot, such as `amazon.com`. That
name still goes through the search list, exactly as with the default. Second, a cluster name
with two dots, such as `orders.payments.svc`, is now tried as written first. CoreDNS doesn't
own that name, so it forwards the query to the *upstream* DNS server (the server outside the
cluster that CoreDNS sends non-cluster names to). The query fails there, and only then does the
search list find the Service. For names like this, `ndots:2` adds queries instead of saving
them.

So pick the lowest `ndots` value that keeps your own Service names working. For external names
with one dot, such as `amazon.com`, a trailing dot is the only fix that skips the search list,
if your client accepts it.

Set `dnsConfig` in the Deployment's Pod template, not by hand on one Pod, so every replica gets
it.

## Fix 3: Cache DNS on Every Node

The first two fixes reduce the number of queries. *NodeLocal DNSCache* reduces how far each query
travels. It runs a small DNS cache as a DaemonSet, so there is one copy on every node. Pods ask
the cache on their own node first, and only cache misses leave the node. The cache also keeps
the wasted `NXDOMAIN` answers, so repeated search-list attempts are answered locally.

This is what took OLX Autos from about 3000 ms to under 50 ms, together with the trailing dot.
The cluster administrator installs it once for the whole cluster, and applications don't change.
Setup depends on the cluster, so follow the
[Kubernetes guide](https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/). I didn't
test NodeLocal DNSCache for this post.

## Which Fix to Use

| Situation | Fix |
| --- | --- |
| HTTPS APIs and most external names (two or more dots) | `ndots: "2"` in the Pod template |
| A one-dot name, with a client you've tested with the dot | Trailing dot |
| A large cluster where CoreDNS is the bottleneck | NodeLocal DNSCache, plus one of the above |

You can use more than one. For example, run NodeLocal DNSCache on the cluster and set `ndots: "2"`
on the services that call external APIs the most.

## Clean Up

```sh
kubectl delete -f pods.yaml
```

Deleting the Pods doesn't turn off query logging. The `log` plugin stays on until you remove the
`log` line from the `coredns` ConfigMap and restart CoreDNS. Don't leave it on in a real cluster,
because it writes a line for every query.

## Summary

- Pods resolve names through a search list. With the default `ndots:5`, any name with fewer than
  five dots tries every cluster suffix first.
- For an external name like `amazon.com` or `api.github.com`, that's 8 DNS queries, and 6 of
  them are wasted.
- A trailing dot (`api.github.com.`) skips the search list. It cut the count to 2 queries and
  made lookups about four times faster in my test, but some HTTPS servers and clients reject a
  host name that ends with a dot, so test it first.
- `ndots: "2"` in the Pod template does the same for names with two or more dots, without
  changing code. Names with one dot still go through the search list.
- At large scale, add NodeLocal DNSCache so most queries never leave the node.

As a next step, run `./count-queries.sh` against the external names your busiest service uses,
and count how many queries each one really costs.

## Resources

- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/), including Pod `dnsConfig`
- [Using NodeLocal DNSCache in Kubernetes clusters](https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/)
- [Scale from 100 to 10,000 pods on Amazon EKS](https://aws.amazon.com/blogs/containers/scale-from-100-to-10000-pods-on-amazon-eks/), AWS Containers blog
- [CoreDNS `log` plugin](https://coredns.io/plugins/log/)
