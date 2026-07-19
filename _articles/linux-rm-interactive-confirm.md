---
layout: post
title: "Delete with Confirmation Using rm -i"
date: 2022-11-03
author: Quan Huynh
tags: [linux, tips]
image: /assets/images/posts/linux-rm-interactive-confirm/cover.png
---

Sometimes we need to delete all the files in a directory, but there are a few files
in there we don't want to delete. Normally we'd write a fiddly wildcard. You can
solve this by adding the `-i` option to the delete command — now, before deleting,
the command will ask whether you really want to delete each item, and you can
confirm exactly what you want removed.

```bash
rm -i *
```
