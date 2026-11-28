---
layout: post
title: "Put CloudFront in Front of Your Application Load Balancer"
subtitle: "Why an API gets faster behind CloudFront even when nothing is cached, how to measure it with curl, and how to set it up so nobody can bypass it."
date: 2026-11-27
author: Quan Huynh
tags: [aws, cloudfront, alb, performance, networking]
image: /assets/images/posts/aws-alb-cloudfront-performance/cover.svg
---

Your API runs behind an Application Load Balancer (ALB) in Singapore. Users in Singapore get fast
responses. Users in Tokyo, Sydney, or Frankfurt wait longer, and most of that extra wait is not
your code. It is the network: every new connection needs several round trips to Singapore before
the first byte of the response comes back.

Amazon CloudFront is the content delivery network (CDN) from AWS. It runs servers, called *edge
locations*, in many cities. Most people use it to cache images and files. This post covers a less
obvious use: putting CloudFront in front of an ALB that serves a dynamic API, with caching turned
off, and still making the API faster.

The post first explains where the time goes and what CloudFront changes. Then it shows how to
measure the difference with `curl`, and how to set up CloudFront so that clients can't skip it and
call the ALB directly. If you only need the setup, go to [Set It Up](#set-it-up).

A few CloudFront terms appear throughout:

- *Distribution*: one CloudFront configuration, with its own domain name.
- *Origin*: the server CloudFront forwards requests to. Here, the ALB.
- *Viewer*: the client that sends the request to CloudFront, such as a browser or mobile app.
- *Cache behavior*: the settings CloudFront applies to a URL path pattern, such as `/api/*`.

> **Note:** I ran the `curl` command below for this version of the post. The CloudFront and ALB
> settings come from the CloudFront Developer Guide; I did not build them in an AWS account for
> this version. The "before and after" numbers come from the first version of this post (2024),
> and I explain what they do and don't show.

## Where the Time Goes

When a browser or app calls `https://api.example.com/orders` for the first time, it needs:

1. A DNS lookup.
2. A TCP connection: one round trip to the server.
3. A TLS handshake to set up encryption: one more round trip with TLS 1.3, two with TLS 1.2.
4. The request itself, and waiting for the first byte of the response.

A *round trip* is one message to the server plus its answer. Between Tokyo and Singapore, one
round trip takes tens of milliseconds. So before your API does any work, the user has already
waited for two or three round trips for TCP and TLS, plus one more for the request itself. On the
public internet, the route for each packet is also outside your control, and it isn't always the
shortest one.

## What CloudFront Changes Without Caching

With CloudFront in front, the user connects to the nearest edge location instead of to Singapore.

![Two rows. ALB only: a user in Tokyo opens TCP and TLS all the way to the ALB in Singapore over the public internet, several long round trips. CloudFront + ALB: the user's TCP and TLS 1.3 handshakes end at a nearby CloudFront edge with short round trips, and the edge forwards the request to the ALB over the AWS network on a keep-alive connection that is already open.](/assets/images/posts/aws-alb-cloudfront-performance/alb-with-and-without-cloudfront.svg)

Three things change, and none of them depend on caching:

1. **The handshakes happen nearby.** TCP and TLS now end at the edge location, a few milliseconds
   away. CloudFront supports TLS 1.3 for viewers, and a TLS 1.3 handshake takes one round trip
   instead of the two that TLS 1.2 needs.
2. **The long distance runs on the AWS network.** The edge location forwards the request to your
   ALB over the AWS network, not over whatever route the public internet picks.
3. **CloudFront reuses its connections to your ALB.** After a response, CloudFront can keep the
   connection to the origin open, so a later request can skip a new TCP connection and TLS
   handshake to Singapore. The *keep-alive timeout* setting controls how long CloudFront keeps an
   idle origin connection open. The default is 5 seconds, and it only works if your origin also
   allows persistent connections. CloudFront can also use HTTP/2 to the origin, which carries
   several requests over one connection.

Caching is an extra gain on top of these three. CloudFront can answer cacheable responses (images,
static files, or API responses that are the same for every user) from the edge, without calling
your ALB. Responses that differ per user or change often should not be cached. For those paths
you turn caching off, and the three gains above still apply.

## Measure It Yourself

The `-w` option makes `curl` print timing for each phase of a request. The example below uses
`https://aws.amazon.com/` as the target. For your own test, replace it with your ALB's domain, then
with your CloudFront domain, and run both from a machine near your users.

```sh
curl -s -o /dev/null -w 'dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total}\n' https://aws.amazon.com/
```

```text
dns=0.003932 connect=0.011800 tls=0.020388 ttfb=0.250790 total=0.815526
```

Each value is in seconds, counted from the start of the request. The values add up, so each one
includes the phases before it:

- `connect`: the TCP connection is open. Here that took 12 ms, because `aws.amazon.com` is served
  from a nearby CloudFront edge.
- `tls`: the TLS handshake is done, at 20 ms.
- `ttfb` (time to first byte): the first byte of the server's answer arrived, at 251 ms.
- `total`: the full response arrived, at 816 ms.

Run the command three to five times and ignore the first run. The first run includes a DNS lookup
that later runs answer from a local cache. In my first run, `dns` was 82 ms; in the next two runs
it was 4 ms. The output above is from one of those later runs.

Against an ALB far from you, expect `connect` and `tls` to be much larger, because each of those
steps needs a full round trip to the Region. That is the part CloudFront shortens.

### The numbers from the first version of this post

When I first wrote this post in 2024, I measured one endpoint both ways with the browser's
developer tools:

| | ALB only | CloudFront + ALB |
| --- | --- | --- |
| Page load time | about 750 ms | about 440 ms |
| Initial connection | 278.8 ms | 17.5 ms |

The initial connection shows the difference most clearly: the handshake moved from the far-away
Region to a nearby edge. I didn't record the Region or the network I measured from, so treat these
numbers as one example, not a benchmark. To get numbers for your own users, use the `curl` command
above.

## Set It Up

The steps below follow the order you would do them in. Setting names match the CloudFront
console.

### 1. Create the distribution with the ALB as origin

- **Origin:** your ALB. Set the origin protocol to "HTTPS only", so the connection from CloudFront
  to the ALB is encrypted, and set the minimum origin SSL protocol to TLSv1.2 or later. If your ALB
  listener supports HTTP/2, set "Origin HTTP version" to HTTP/2. (CloudFront offers HTTP/2 to the
  origin only over HTTPS, with TLSv1.2 or later.)
- **Viewer protocol policy:** "Redirect HTTP to HTTPS", so clients always use TLS to the edge.
- **Alternate domain name:** `api.example.com`, the name your clients call. Attach an ACM
  certificate for that name. CloudFront requires this certificate to be in the US East
  (N. Virginia) Region, `us-east-1`, even if your ALB runs elsewhere.

After the distribution is deployed, point the DNS record for `api.example.com` to the
distribution's domain name instead of the ALB.

### 2. Turn off caching for the dynamic API

A cache behavior uses two policies. The *cache policy* decides what CloudFront caches. The *origin
request policy* decides which parts of the viewer's request CloudFront passes to the origin. For
the API paths, use these managed policies:

- **Cache policy:** `CachingDisabled`. CloudFront caches nothing, so every request goes to your
  ALB.
- **Origin request policy:** `AllViewer`. CloudFront forwards all of the viewer's headers, cookies,
  and query strings, including `Host`. Your ALB listener rules and your application then see the
  request as the client sent it.

AWS also offers `AllViewerExceptHostHeader`, which forwards everything except `Host`. The docs
intend it for API Gateway and Lambda origins, which expect their own domain in `Host`. With an ALB
that routes on `api.example.com`, that policy would send a different `Host` value, so start with
`AllViewer`.

> **Warning:** when CloudFront forwards `Host` and talks HTTPS to the ALB, the certificate on the
> ALB must include `api.example.com`. The CloudFront docs say the origin's certificate must match
> either the origin domain name or the forwarded `Host` header. An ALB with only a certificate for
> some other name fails this check, and viewers get errors instead of your API. Add a certificate
> for `api.example.com` to the ALB's HTTPS listener (ACM certificates work on an ALB).

If you also serve static files, add a separate cache behavior for those paths (for example
`/static/*`) with the `CachingOptimized` policy. CloudFront then serves those files from the edge.

### 3. Make CloudFront the only way in

If the ALB is still reachable from the internet, clients can skip CloudFront. Any protection you
add at the edge, such as AWS WAF, then does nothing for those requests. There are two ways to
close that path.

**Option A: VPC origins.** This is the option I would pick for a new setup. Put the ALB in private
subnets with no public access, and create a *VPC origin* for it in CloudFront. CloudFront reaches
the ALB through network interfaces that it manages in your subnets. The ALB has no public address,
so CloudFront is the only way in. VPC origins work with ALBs, Network Load Balancers, and EC2
instances, in the Regions listed in the CloudFront docs.

**Option B: a public ALB that only accepts CloudFront.** Use this when the ALB must stay
internet-facing, for example in a Region without VPC origin support. It takes two controls:

- In the ALB's security group, allow inbound traffic only from the AWS-managed prefix list for
  CloudFront, `com.amazonaws.global.cloudfront.origin-facing`. This list contains the IP ranges
  that CloudFront uses to connect to origins.
- In CloudFront, add a custom origin header with a secret value, for example `X-Origin-Verify`
  with a long random string. On the ALB listener, add a rule that forwards requests only when that
  header has the right value, and make the default action return 403.

You need both controls. The prefix list blocks traffic that doesn't come from CloudFront. But
every CloudFront distribution, including someone else's, connects from the same IP ranges, so the
secret header is what proves the request came through *your* distribution. AWS recommends
rotating the header value from time to time.

> **Warning:** Add the header in CloudFront and wait for the distribution to deploy before you
> change the ALB's default action to 403. In the other order, the ALB rejects CloudFront's
> requests too, and every client gets 403 until the header is in place.

## When Not to Use It

- **All your users are close to the Region.** If everyone is in the same city as the ALB, the
  handshakes are already short. Measure first.
- **The traffic is internal.** Service-to-service calls inside AWS don't benefit from a CDN at the
  edge of the internet.
- **Your requests don't fit CloudFront's limits.** CloudFront is one more layer, with its own
  limits and its own bill. For example, CloudFront waits 30 seconds by default for the origin to
  respond. Check that your long-running requests and large uploads fit before you move them
  behind CloudFront.

## Summary

- For far-away users, most of the time to open a new connection goes to TCP and TLS round trips,
  not to your application.
- CloudFront ends those handshakes at a nearby edge, carries the request over the AWS network, and
  reuses open connections to your ALB. That speeds up an API even with caching turned off.
- You can measure the effect with `curl -w`; compare `connect` and `tls`.
- For a dynamic API, use `CachingDisabled` with `AllViewer`, and cache only the static paths.
- To make CloudFront the only way in, use a VPC origin with a private ALB, or the CloudFront prefix
  list plus a secret header.

As a next step, run the `curl` command against your ALB from a machine near your users. Then run
it against a CloudFront distribution in front of the same ALB, and compare `connect` and `tls`.

## Resources

- [Origin settings](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistValuesOrigin.html), including keep-alive timeout and origin HTTP version
- [Restrict access with VPC origins](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-vpc-origins.html)
- [Restrict access to Application Load Balancers](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/restrict-access-to-load-balancer.html)
- [Managed cache policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html) and [managed origin request policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html)
- [Supported protocols and ciphers between viewers and CloudFront](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html)
