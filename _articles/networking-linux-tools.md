---
layout: post
title: "Linux Networking Tools"
series: "Networking for DevOps"
series_url: /networking-series/
part: 8
date: 2024-05-01
author: Quan Huynh
tags: [networking, devops, linux]
image: /assets/images/posts/networking-linux-tools/cover.png
---

Some important networking tools that DevOps engineers need to know.

**Ping**

Used to check whether the machine running the `ping` command can connect to a host
using the Internet Protocol (IP). For example:

```
ping google.com

PING google.com (142.250.207.78) 56(84) bytes of data.
64 bytes from ... (142.250.207.78): icmp_seq=1 ttl=115 time=48.4 ms
64 bytes from ... (142.250.207.78): icmp_seq=2 ttl=115 time=44.2 ms
--- google.com ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
```

**Telnet**

Checks connectivity to a port on a server. For example, checking connectivity to
port 3306 of a server:

```
telnet 151.101.65.124 3306
```

**Traceroute**

Displays the route and measures the transit delay of packets across an IP network.
For example:

```
traceroute google.com

traceroute to google.com (172.217.24.110), 30 hops max, 60 byte packets
...
```

**Netstat**

Displays active network connections on a machine, often used to check whether a
service is running. For example, checking whether Postgres is running on port 5432:

```
netstat -ltnp | grep 5432
```

**Nmap**

Often used to scan which ports are open on a host. For example:

```
nmap -p 1-1000 151.101.65.124

Starting Nmap 7.80 ( https://nmap.org ) at 2024-05-01 15:22 +07
Nmap scan report for 151.101.65.124
Host is up (0.040s latency).
Not shown: 998 filtered ports
PORT    STATE SERVICE
80/tcp  open  http
443/tcp open  https
```

**Tcpdump**

Used to capture and analyze network traffic. For example:

```
tcpdump -i eth0

tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
...
```

**Nslookup**

Used to look up information about a domain, such as its DNS name server or server
IP.

```
nslookup devopsvn.tech

Server:         172.29.128.1
Address:        172.29.128.1#53
```
