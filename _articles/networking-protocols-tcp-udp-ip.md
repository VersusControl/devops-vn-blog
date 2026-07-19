---
layout: post
title: "Protocols: TCP/UDP/IP"
series: "Networking for DevOps"
series_url: /networking-series/
part: 2
date: 2024-02-07
author: Quan Huynh
tags: [networking, devops]
image: /assets/images/posts/networking-protocols-tcp-udp-ip/cover.png
---

A protocol is a set of rules that define how data is transmitted and received
between devices. It ensures data transmission and lets different systems
understand and interact with each other. Some common protocols are TCP, HTTP, and
SMTP. The key protocol concepts we need to understand are: TCP, UDP, and IP.

**TCP (Transmission Control Protocol):**

- TCP operates at the transport layer of the OSI model. It establishes a
  connection between two devices before exchanging data, ensuring reliable,
  ordered transmission.
- It splits data into packets, assigns sequence numbers, and uses acknowledgment
  messages to ensure reliable delivery. It is a connection-oriented protocol,
  meaning it establishes, maintains, and terminates a connection to exchange data.

**UDP (User Datagram Protocol):**

- UDP also operates at the transport layer of the OSI model. However, UDP is
  *connectionless*, meaning that when sending data it doesn't need to establish a
  connection between the two devices — it just identifies the destination device
  and sends the data.
- UDP doesn't need to confirm whether the data reached the destination, so it's
  faster than TCP. It's suitable for real-time applications such as video
  streaming or online gaming.

**IP (Internet Protocol):**

- IP operates at the network layer and is a fundamental part of the TCP/IP suite.
  It handles addressing and routing to ensure data packets reach the correct
  destination.
- Each device on a network is assigned a unique IP address.

In summary: the Internet Protocol handles addressing and routing data to the
correct destination. TCP and UDP handle the data between devices — TCP uses a
connection-oriented approach (slow but reliable), while UDP uses a connectionless
approach (fast but not guaranteed).
