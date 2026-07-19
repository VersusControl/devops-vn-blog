---
layout: post
title: "Speed Up the find Command with -quit"
date: 2022-11-03
author: Quan Huynh
tags: [linux, tips]
image: /assets/images/posts/linux-find-quit-faster-search/cover.png
---

By default, the `find` command searches through all files matching the pattern
you pass in. You can speed up `find` by telling it to stop as soon as it finds the
first file matching your pattern. **This is really handy when you need to find
which directory a system log file lives in.**

```bash
find / -name "app.log" -print -quit
```
