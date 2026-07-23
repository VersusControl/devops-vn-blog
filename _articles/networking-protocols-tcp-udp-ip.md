---
layout: post
title: "Protocols: TCP/UDP/IP"
series: "Networking for DevOps"
series_url: /networking-series/
part: 2
date: 2024-02-07
author: Quan Huynh
tags: [networking, devops]
image: /assets/images/posts/networking-protocols-tcp-udp-ip/cover.svg
---

A **protocol** is simply an agreed set of rules for how devices talk to each other —
how data is packaged, sent, and confirmed. Because both sides follow the same rules,
completely different systems can understand one another. There are many protocols
(HTTP, SMTP, DNS…), but the three foundations every DevOps engineer should know are
**TCP**, **UDP**, and **IP**.

## IP — the addressing system

**IP (Internet Protocol)** works at the **Network layer**. Its job is addressing and
routing: making sure a packet of data reaches the right destination. Every device on a
network gets a unique **IP address**, and IP uses it to move packets from one machine
to another — a bit like the postal system reading the address on an envelope.

IP gets the packet to the right *building*. But which *application* on that machine
should receive it, and should we double-check it arrived? That's where TCP and UDP come
in. Both live at the **Transport layer**, one level above IP.

## TCP — reliable, like a phone call

**TCP (Transmission Control Protocol)** is *connection-oriented*. Before sending
anything, the two devices "shake hands" to open a connection — like dialing someone and
waiting for them to say "hello" before you start talking.

TCP then splits your data into packets, numbers them, and waits for the other side to
**acknowledge** each one. If a packet goes missing, TCP resends it. The result is
**reliable, in-order delivery** — nothing lost, nothing scrambled. The trade-off is a
little extra overhead and delay. Web pages, APIs, databases, and SSH all use TCP.

## UDP — fast, like a postcard

**UDP (User Datagram Protocol)** is *connectionless*. There's no handshake and no
acknowledgements — it just addresses the data and fires it off, like dropping a postcard
in the mailbox and hoping it arrives.

Because it skips all the checking, UDP is **faster and lighter** than TCP, but delivery
isn't guaranteed. That's a perfect fit for things where speed matters more than perfect
accuracy: live video, voice calls, online games, and DNS lookups.

## TCP vs. UDP at a glance

| | **TCP** | **UDP** |
|---|---|---|
| Connection | Yes (handshake first) | No |
| Reliability | Guaranteed & in order | Best-effort |
| Speed | Slower (more checking) | Faster (no checking) |
| Good for | Web, APIs, SSH, databases | Video, voice, games, DNS |

**In short:** IP handles *where* the data goes; TCP and UDP handle *how* it gets there —
TCP the careful way, UDP the fast way.

In the next post, we'll look at **ports** — how a single server tells apart the many
kinds of traffic arriving at the same IP address.
