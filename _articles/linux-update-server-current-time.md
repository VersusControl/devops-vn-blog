---
layout: post
title: "Update a Server's Current Time"
date: 2022-11-06
author: Quan Huynh
tags: [linux, tips]
image: /assets/images/posts/linux-update-server-current-time/cover.png
---

When your server goes down for a while and then comes back up, its clock can
sometimes drift out of sync with the real time. To reset the server's current
time, do the following.

```bash
CURRENT=$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z
```

```bash
sudo date -s "$CURRENT"
```
