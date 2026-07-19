---
layout: post
title: "Preview a Command with echo Before Running rm"
date: 2023-02-07
author: Quan Huynh
tags: [linux, tips]
image: /assets/images/posts/linux-echo-preview-before-rm/cover.png
---

Combine the `echo` command with another command to preview what that command will
do. For example, preview which files would be deleted with `echo`. If you want to
run a delete command but aren't sure exactly which files will be removed, use
`echo` to preview first:

```bash
echo rm -rf *
```

Very handy. 😁
