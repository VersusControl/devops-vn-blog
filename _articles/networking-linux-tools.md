---
layout: post
title: "Linux Networking Tools"
series: "Networking for DevOps"
series_url: /networking-series/
part: 8
date: 2024-05-01
author: Quan Huynh
tags: [networking, devops, linux]
image: /assets/images/posts/networking-linux-tools/cover.svg
---

Everything we've covered so far — layers, protocols, ports, routing, DNS — comes
together when you're staring at a broken connection and need to find out *why*. These
are the command-line tools DevOps engineers reach for to test and debug networks. For
each one, the trick is knowing **what to look for** in the output.

## Ping — is the host reachable?

`ping` checks whether your machine can reach another host, and how long it takes.

```
ping google.com

PING google.com (142.250.207.78) 56(84) bytes of data.
64 bytes from ... (142.250.207.78): icmp_seq=1 ttl=115 time=48.4 ms
64 bytes from ... (142.250.207.78): icmp_seq=2 ttl=115 time=44.2 ms
--- google.com ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
```

**Look at:** `0% packet loss` (good) and the `time` (latency). No reply at all usually
means the host is down, the network is blocked, or a firewall is dropping ICMP.

## Telnet / nc — is a specific port open?

`ping` only tells you the host is up — not whether the *service* is listening. To test a
port, use `telnet` (or the more modern `nc`, netcat):

```
telnet 151.101.65.124 3306
nc -vz 151.101.65.124 3306
```

**Look at:** a "Connected" / "succeeded" message means the port is open; "Connection
refused" or a hang means it's closed or firewalled. This is the fastest way to check
"can my app actually reach the database?"

## Traceroute / mtr — where does traffic go (or stop)?

`traceroute` shows every hop a packet passes through on its way to the destination.

```
traceroute google.com

traceroute to google.com (172.217.24.110), 30 hops max, 60 byte packets
...
```

**Look at:** the hop where replies stop or times spike — that's often where the problem
is. `mtr` combines ping and traceroute into a live, continuously updating view and is
usually the better tool for spotting where packets are being lost.

## ss / netstat — what's listening on this machine?

`ss` is the modern replacement for `netstat`; both show active connections and listening
ports. Handy for confirming a service actually came up on the port you expect:

```
ss -ltnp | grep 5432      # modern
netstat -ltnp | grep 5432 # older, still common
```

**Look at:** a `LISTEN` line on the port means the service is up. Nothing means it never
started or bound to a different address.

## nmap — which ports are open on a host?

`nmap` scans a host to see which ports are open — great for verifying firewall rules
(scan only systems you're allowed to).

```
nmap -p 1-1000 151.101.65.124

Starting Nmap 7.80 ( https://nmap.org )
Nmap scan report for 151.101.65.124
Host is up (0.040s latency).
PORT    STATE SERVICE
80/tcp  open  http
443/tcp open  https
```

**Look at:** the `open` ports. Unexpected open ports are a security red flag; missing
ones mean a firewall or the service is blocking access.

## tcpdump — what's actually on the wire?

When you need to see the raw traffic, `tcpdump` captures and prints packets.

```
tcpdump -i eth0 port 443
```

**Look at:** whether packets are flowing in both directions. It's the tool of last resort
when nothing else explains the behaviour.

## dig / nslookup — resolve a domain

To check what a domain name resolves to, use `dig` (preferred by DevOps for its detailed
output) or the simpler `nslookup`:

```
dig devopsvn.tech +short
nslookup devopsvn.tech
```

**Look at:** the returned IP and which DNS server answered. If a site is unreachable but
resolves to the wrong (or no) address, the problem is DNS, not the server.

## curl — test an HTTP endpoint (Layer 7)

`curl` checks a service at the application layer — is the API actually responding?

```
curl -I https://devopsvn.tech
```

**Look at:** the HTTP status code (`200` good, `5xx` server error) and TLS/redirect
behaviour.

> A quick note on modern vs. legacy: `ss`, `ip`, `dig`, and `mtr` are the current tools;
> `netstat`, `route`/`ifconfig`, and `nslookup` are older but still everywhere, so it's
> worth knowing both.

## Wrapping up the series

That completes our **Networking for DevOps** series. We started at the OSI model and
worked down through protocols, ports, subnetting, routing, DNS, and VPNs — and finished
with the tools to test them all. You don't need to be a network engineer to be a great
DevOps engineer, but knowing *which layer a problem lives at* and *which tool answers the
question* will save you countless hours of debugging.
