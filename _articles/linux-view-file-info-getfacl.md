---
layout: post
title: "View File Info with getfacl"
date: 2022-11-04
author: Quan Huynh
tags: [linux, tips]
image: /assets/images/posts/linux-view-file-info-getfacl/cover.png
---

We usually use `ls -l` to view file ownership and permissions, but its output is
fairly hard to read. Try the `getfacl` command instead — its output is much easier
to read.

```bash
getfacl file.txt
```
