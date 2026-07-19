---
layout: post
title: "Subnetting"
series: "Networking for DevOps"
series_url: /networking-series/
part: 4
date: 2024-02-19
author: Quan Huynh
tags: [networking, devops]
image: /assets/images/posts/networking-subnetting/cover.png
---

The important concepts DevOps needs to grasp are IP, subnetting, and CIDR notation.

**IP (Internet Protocol)** comes in two versions, IPv4 and IPv6:

- IPv4 uses 32 binary bits, divided into 4 groups of 8 bits, as the address — for
  example, `192.0.2.126` is an IPv4 address. With 32 bits, IPv4 has a maximum of
  about 4 billion IP addresses.
- IPv6 is the newest version of the Internet Protocol, developed to upgrade and
  replace IPv4. IPv6 uses 128-bit addresses, for a maximum of 340 undecillion IP
  addresses.

Today, IPv4 is more commonly used. IPv4 is divided into two main parts: the network
part (Network ID) and the host part (Host ID). The network part identifies the
network's address, and the host part identifies a device's address within the
network.

IPv4 has ranges reserved for private networks:

- 10.0.0.0 to 10.255.255.255
- 172.16.0.0 to 172.31.255.255
- 192.168.0.0 to 192.168.255.255

We usually use the ranges above when designing internal networks.

**Subnetting**

Subnetting is the process of dividing a network into smaller subnetworks (subnets)
to optimize IP address usage and provide better management and security for the
network.

Subnetting lets you split an IPv4 address into new network and host parts, helping
create subnets with their own IP addresses for each subnet.

When designing a network, we usually divide it into smaller parts. For example,
with the range 172.16.0.0 to 172.31.255.255, we split it into smaller networks for
easier management:

- 172.16.0.0 to 172.16.15.255
- 172.16.16.0 to 172.16.31.255
- …

We use CIDR notation to define how the network is divided.

**CIDR notation**

CIDR (Classless Inter-Domain Routing) notation is a method for representing IP
addresses. CIDR notation consists of an IP address followed by a slash and a
decimal number — for example `192.168.1.0/24`, where `192.168.1.0` is the IP
address and `/24` is the slash notation that determines how many device addresses
are in that subnet: 192.168.1.0/24 ⇒ 192.168.1.0 to 192.168.1.255. For the detailed
calculation, see [CIDR](https://www.geeksforgeeks.org/classless-inter-domain-routing-cidr/).

At work, we use a tool to calculate it — see this page:
[CIDR to IPv4 Conversion](https://www.ipaddressguide.com/cidr).

![CIDR notation](/assets/images/posts/networking-subnetting/cidr.png)

For DevOps, when designing a network we need to determine which network ranges we
need and how to divide subnets to accommodate the number of IPs for the services
in our system. For example:

![Subnet design](/assets/images/posts/networking-subnetting/subnet-design.png)

Too many and you waste addresses; too few and you run short. So dividing subnets
at the initial step is very important.
