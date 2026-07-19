---
layout: post
title: "Ports"
series: "Networking for DevOps"
series_url: /networking-series/
part: 3
date: 2024-02-09
author: Quan Huynh
tags: [networking, devops]
image: /assets/images/posts/networking-ports/cover.png
---

A port is a virtual point where network connections start and end. Ports are
virtual gateways on a computer that allow data to be sent and received. Each port
is associated with a specific process or service. Using ports helps a computer
easily distinguish between the different kinds of data coming into it — for
example, port 80 is used for web access, and port 587 is used for email.

Network ports are identified by numbers ranging from 0 to 65535. Ports 0 to 1023
are considered well-known ports, used for standard network services such as HTTP
(port 80), FTP (port 21), Telnet (port 23), and SSH (port 22). Ports 1024 to 49151
are used for custom applications and services. Ports 49152 to 65535 are used for
temporary or ephemeral connections.

Ports operate at layer 4 (the transport layer) of the OSI model.

![Ports at OSI layer 4](/assets/images/posts/networking-ports/ports-layer4.png)

The Internet Protocol (IP) operates at layer 3 (the network layer) and is
responsible for routing a data packet to a given IP address. TCP and UDP operate
at layer 4 (the transport layer) and determine which port on the server a data
packet should go to — the TCP and UDP headers include a field to specify the port.
