---
layout: post
title: "DNS"
series: "Networking for DevOps"
series_url: /networking-series/
part: 6
date: 2024-04-07
author: Quan Huynh
tags: [networking, devops]
image: /assets/images/posts/networking-dns/cover.png
---

DNS, or the Domain Name System, translates easy-to-remember domain names into
computer-friendly IP addresses. It helps locate servers, balance web traffic across
servers, and redirect user requests.

For example, suppose we own a server with the address 17.297.28.12 and deploy a
website on it. We want users to visit our website, but we can't give them the
address 17.297.28.12 because it's hard to remember and not friendly ⇒ that's why
DNS exists. With DNS, we create a domain name — say `abc.vn` — and map it to the
address 17.297.28.12. Then we just give users the domain name `abc.vn`.

As a DevOps fresher, you need to grasp a few basic DNS records, as shown below:

![Basic DNS records](/assets/images/posts/networking-dns/dns-records.png)

Learn more about DNS here: [What is DNS](https://www.cloudflare.com/learning/dns/what-is-dns/).
