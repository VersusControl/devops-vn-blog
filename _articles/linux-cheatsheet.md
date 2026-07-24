---
layout: post
title: "The DevOps Linux Cheatsheet"
date: 2023-02-07
author: Quan Huynh
tags: [linux, docker, tips]
image: /assets/images/posts/linux-cheatsheet/cover.svg
---

A collection of short, practical Linux tips I reach for during everyday work — from
listing files more clearly to deleting them safely, searching faster, and cleaning up
Docker. Keep this page handy as a quick reference.

## Listing Files

### List files vertically with `ls -1`

We usually list the files in a directory with `ls`. But when there are many files, the
output wraps across the line and becomes hard to read. Add the `-1` option to list
files one per line, which is easier to scan.

```bash
ls -1
```

### Group files by extension with `ls -lX`

By default, `ls -l` orders files in a way that mixes extensions together. Add the `-X`
option to group files by extension.

```bash
ls -lX
```

### View file info with `getfacl`

We usually use `ls -l` to view file ownership and permissions, but its output is hard
to read. Try `getfacl` instead — it presents the same information in a much clearer
layout.

```bash
getfacl file.txt
```

## Working with File Contents

### Remove empty lines with `grep`

Use `grep` with the `.` pattern to strip empty lines from a file — `.` matches any line
that contains at least one character.

```bash
grep . input.txt
```

## Deleting Files Safely

### Confirm each deletion with `rm -i`

Sometimes you need to delete most files in a directory but keep a few. Instead of
crafting a fiddly wildcard, add the `-i` option: `rm` will ask for confirmation before
removing each item, so you delete exactly what you intend to.

```bash
rm -i *
```

### Preview a command with `echo` before running `rm`

Prefix a command with `echo` to preview what it *would* do without actually running it.
This is perfect for double-checking which files a wildcard will match before you delete
them:

```bash
echo rm -rf *
```

Once you're happy with the list, drop the `echo` and run it for real. Very handy. 😁

## Finding Files Faster

### Stop searching early with `find -quit`

By default, `find` keeps searching through every file that matches your pattern. Add
`-quit` to stop as soon as it finds the first match — great when you just need to know
which directory a log file lives in.

```bash
find / -name "app.log" -print -quit
```

## Date and Time

### Get the day of the year with `date`

The `date` command shows the current time. To get the day of the year (1–366), use the
`'+%j'` format.

```bash
date '+%j'
```

### Fix a server's clock after downtime

When a server is down for a while and comes back up, its clock can drift out of sync
with real time. Fetch the current time from a reliable source and set it:

```bash
CURRENT=$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z
```

```bash
sudo date -s "$CURRENT"
```

## Docker

### Remove all exited containers

When working with Docker you'll often want to clear out every container in the *exited*
state, instead of removing them one by one with `docker rm <container-id>`. Do it in one
line:

```bash
docker rm $(docker ps -a -f status=exited -q)
```

## Wrapping Up

That's the cheatsheet for now. Each of these is a small trick on its own, but together
they save real time over a day of work at the terminal. Bookmark this page and come back
whenever you need a quick reminder.
