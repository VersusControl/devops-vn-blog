---
layout: post
title: "List Files Vertically with ls -1"
date: 2022-11-03
author: Quan Huynh
tags: [linux, tips]
image: /assets/images/posts/linux-ls-vertical-list/cover.png
---

We usually list all files in a directory with the `ls` command. But sometimes,
when there are too many files, the output is hard to read because it wraps across
the line. You can add the `-1` option so files are listed vertically, which can be
a bit easier to read.

```bash
ls -1
```
