---
layout: post
title: "Remove All Exited Docker Containers"
date: 2022-11-18
author: Quan Huynh
tags: [linux, docker, tips]
image: /assets/images/posts/linux-remove-exited-containers/cover.png
---

When working with Docker, you'll often want to remove all containers in the
*exited* state instead of typing them out one by one with `docker rm <container-id>`.
Do it like this:

```bash
docker rm $(docker ps -a -f status=exited -q)
```
