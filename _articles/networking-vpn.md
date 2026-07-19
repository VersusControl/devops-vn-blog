---
layout: post
title: "Virtual Private Network (VPN)"
series: "Networking for DevOps"
series_url: /networking-series/
part: 7
date: 2024-04-28
author: Quan Huynh
tags: [networking, devops]
image: /assets/images/posts/networking-vpn/cover.png
---

A Virtual Private Network (VPN) is an internet security service that lets users
access the internet as if they were connected to a private network. It encrypts
internet communications and provides a high level of anonymity.

Some of the most common reasons people use a VPN are to protect against snooping on
public WiFi, to bypass internet censorship, or to connect to a company's internal
network for remote work.

![Common VPN uses](/assets/images/posts/networking-vpn/vpn-uses.png)

Normally, most internet requests are unencrypted. When a user makes an internet
connection — such as visiting a website in a browser — the user's device connects
to their Internet Service Provider (ISP), and the ISP then connects to the internet
to find the appropriate web server to communicate with and fetch the website's
content.

Information about the user is exposed at every step of visiting a website. Because
the user's IP address is exposed throughout the process, the ISP and any other
intermediaries can log the user's browsing history. In addition, the data flowing
between the user's device and the web server is unencrypted; this creates an
opportunity for hackers to spy on the data or carry out attacks against the user,
such as an on-path attack.

![Unencrypted connection](/assets/images/posts/networking-vpn/unencrypted.png)

In contrast, a user who connects to the internet using a VPN service has a higher
level of security and privacy. A VPN connection consists of the following 4 steps:

1. The VPN client connects to the ISP over an encrypted connection.
2. The ISP connects the VPN client to the VPN server, maintaining the encrypted
   connection.
3. The VPN server decrypts data from the user's device and then connects to the
   internet to reach the web server.
4. The VPN server creates an encrypted connection with the client, called a VPN
   tunnel.

![VPN tunnel](/assets/images/posts/networking-vpn/vpn-tunnel.png)

The VPN tunnel between the VPN client and the VPN server passes through the ISP, but
because all the data is encrypted, the ISP can't see the user's activity. The VPN
server's communications with the internet are unencrypted, but the web servers only
record the VPN server's IP address, which gives them no information about the user.
