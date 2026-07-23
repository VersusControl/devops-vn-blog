---
layout: post
title: "Routing"
series: "Networking for DevOps"
series_url: /networking-series/
part: 5
date: 2024-02-22
author: Quan Huynh
tags: [networking, devops]
image: /assets/images/posts/networking-routing/cover.svg
---

**Routing** is the process of directing data packets from a source to a destination —
choosing the best path across one or more networks. The device that does this is a
**router**, and it makes its decision using two things: a **routing table** and a
**routing protocol**. We covered protocols earlier in the series, so here we'll focus
on the routing table.

Think of the routing table as a signpost at a junction: "traffic for *this* range of
addresses goes *that* way." Every packet that arrives gets checked against the signpost
and sent down the matching road.

## The routing table

A routing table is a set of rules that decide which network — and through which
gateway — a packet is forwarded to. Each rule holds a destination range, a gateway, and
a netmask. On Linux you can view it with the modern `ip route` command, or the older
`route -n` / `netstat -rn`:

```
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.29.1.1      0.0.0.0         UG    0      0        0 eth0
172.29.128.0    172.29.1.2      255.255.255.0   U     0      0        0 eth0
172.29.130.0    172.29.1.3      255.255.255.0   U     0      0        0 eth0
```

## Reading a route

The **Destination** and **Genmask** together define the IP range a rule covers.
For example, Destination `172.29.128.0` with Genmask `255.255.255.0` means `/24`
(see the [CIDR guide](https://www.geeksforgeeks.org/classless-inter-domain-routing-cidr/)
or the [CIDR calculator](https://www.ipaddressguide.com/cidr) for the math), which is the
range `172.29.128.0` – `172.29.128.255`.

So any packet addressed to something in `172.29.128.0`–`172.29.128.255` is sent to the
gateway `172.29.1.2`. Packets for `172.29.130.x` go to `172.29.1.3`. The router simply
matches the address to the most specific rule and forwards it.

## The default route

The special entry with Destination `0.0.0.0` and Genmask `0.0.0.0` is the **default
route** — the "everything else" rule. Any packet that doesn't match a more specific
entry is sent here (in this table, to the gateway `172.29.1.1`). This is usually the path
out to the internet. For more, see
[routing tables explained](https://www.geeksforgeeks.org/routing-tables-in-computer-network/).

In the next post, we'll look at **DNS** — the system that turns names like
`devopsvn.tech` into the IP addresses routing relies on.
