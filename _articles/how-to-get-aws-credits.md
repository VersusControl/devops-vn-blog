---
layout: post
title: "How to Get Around $5k in AWS Credits for Your Business"
date: 2023-04-03
author: Quan Huynh
tags: [aws, startup]
image: /assets/images/posts/how-to-get-aws-credits/infrastructure-diagram.png
---

A guide to writing the documentation needed to request AWS credits for a business
that hasn't used AWS before, or for a startup.

## How It Works

First, contact the admin [Lê Sỹ Cường](https://www.facebook.com/sycule) with a
message like: "I have a startup project and need support requesting credits."
Note that your business must have a valid business license and be operating.

## Preparation Guide

1. Buy a domain for your business. You can buy from domain providers such as
   Cloudflare, Hostinger, GoDaddy, and so on. For example, I requested credits
   for the startup "devopsvn" and bought the domain `devopsvn.tech`.

2. Prepare an email account with your business domain suffix, for example
   `admin@devopsvn.tech`. To get this email account, look into **Google
   Workspace**.

3. Give a brief introduction to your project and what you're about to build.

4. Draw the system diagram ("at least" 50% of the system's services must be AWS
   services).

5. Estimate (predict) the system cost — this is the step you should prepare most
   carefully. Do it on the [AWS Pricing Calculator](https://calculator.aws/#/).

6. Write the project documentation in English and send it back to the admin
   [Lê Sỹ Cường](https://www.facebook.com/sycule). Besides the technical document
   (see the example), you also need a pitching deck to introduce the project, as
   if you were raising funds from investors (contact the admin for details).

## Example Document

Domain: [https://devopsvn.tech](https://devopsvn.tech/)

Business: Tech Blog.

Introduction: DevOps VN is a tech blog about DevOps and cloud computing (AWS),
with the desire to help our IT community in Vietnam grow.

Project: Building a website for a tech blog with millions of daily active users.

**Infrastructure Diagram (adapted from Alex Xu)**

![Infrastructure diagram]({{ '/assets/images/posts/how-to-get-aws-credits/infrastructure-diagram.png' | relative_url }})

*Web servers*: Besides communicating with clients, web servers enforce
authentication and rate-limiting.

*Fanout service*: Fanout is the process of delivering a post to all friends. The
fanout service works as follows:

1. Fetch friend IDs from the graph database
2. Get friends' info from the user cache
3. Send the friends list and new post ID to the message queue
4. Fanout workers fetch data from the message queue and store news feed data in
   the news feed cache. You can think of the news feed cache as a
   `<post_id, user_id>` mapping table
5. Store `<post_id, user_id>` in the news feed cache

*News feed service*: gets a list of post IDs from the news feed cache. A user's
news feed is more than just a list of feed IDs — it contains the username,
profile picture, post content, post image, and so on. Thus, the news feed service
fetches the complete user and post objects from the caches (user cache and post
cache) to construct the fully hydrated news feed.

**Cost Estimate**

Attach a link to your system cost estimate at the end. For example, I exported
mine as a PDF. Good luck!
