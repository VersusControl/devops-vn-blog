---
layout: post
title: "Routing"
series: "Networking for DevOps"
series_url: /networking-series/
part: 5
date: 2024-02-22
author: Quan Huynh
tags: [networking, devops]
image: /assets/images/posts/networking-routing/cover.png
---

Routing is the process of managing and directing data packets from a source to a
destination efficiently.

In the image above, a router is used to determine the path of a data packet from
Computer A to Computer B. To do this, the router uses a route table and a protocol.
We covered protocols in a previous post; in this post we'll look at the concept of
the route table.

**Route Table**

A route table in Linux is a set of rules that determine which network and device a
data packet will be forwarded to. It contains information such as IP addresses,
gateways, and network masks. To view the route table, use `route -n` or
`netstat -rn`. For example:

```
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.29.1.1      0.0.0.0         UG    0      0        0 eth0
172.29.128.0    172.29.1.2      255.255.225.0   U     0      0        0 eth0
172.29.130.0    172.29.1.3      255.255.225.0   U     0      0        0 eth0
```

The Destination and Genmask fields determine the IP range a data packet is sent to.
For example, with Destination `172.29.128.0` and Genmask `255.255.225.0` ⇒ `/24`
(for the detailed calculation, see [CIDR](https://www.geeksforgeeks.org/classless-inter-domain-routing-cidr/)),
we get the IP range `172.29.128.0/24`. Using the
[CIDR to IPv4 Conversion](https://www.ipaddressguide.com/cidr) tool, we get the
actual IP range from 172.29.128.0 to 172.29.128.255. So if we call an IP address in
the range 172.29.128.0 to 172.29.128.255, the data packet will be sent to the
gateway `172.29.1.2`.

With Destination `0.0.0.0` and Genmask `0.0.0.0`, it means all IPs not in any of
the ranges above will go through it. For more details on route tables, see:
[Routing Tables in Computer Network](https://www.geeksforgeeks.org/routing-tables-in-computer-network/).
