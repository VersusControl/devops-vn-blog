---
layout: post
title: "Amazon S3 Explained: When Object Storage Beats a Disk"
subtitle: "How object storage differs from a disk, when S3 should replace the uploads folder on your server, and how to keep a bucket private, fast, and affordable."
date: 2026-11-28
author: Quan Huynh
tags: [aws, s3, storage, object-storage]
image: /assets/images/posts/aws-why-use-s3/cover.svg
---

Many applications save user uploads to a folder on the server, such as `/var/www/uploads`. This
works until the disk fills up, or the server dies and takes the only copy of every file with it.
It also breaks when you add a second server behind a load balancer: a user whose request reaches
server A can't see an image that was uploaded to server B.

*Object storage* avoids these problems because the files no longer live on any one server. Amazon
S3 (Simple Storage Service) is the object storage service on AWS. Teams use it for uploads,
backups, logs, static websites, and data lakes.

After reading this post, you should be able to:

- explain how object storage differs from a disk and from a shared file system;
- choose between S3, EBS, and EFS for a given job;
- keep a bucket private and give access through presigned URLs and CloudFront;
- spot outdated S3 advice in older tutorials, including the first version of this post.

> **What was tested:** the facts and limits come from the Amazon S3 User Guide and FAQ, read on
> 2026-11-27. I didn't run the CLI commands in an AWS account for this version of the post; they
> follow the documented syntax.

## What Object Storage Is

A disk stores *files* in *folders*. You can open a file and change byte 1,000 in place. Object
storage uses three different ideas:

- A *bucket* is a container for objects. Its name must be unique across all AWS accounts in the
  same AWS partition. Most people work only in the standard commercial Regions, so in practice
  the name must not be taken by anyone else on AWS. (China and AWS GovCloud are separate
  partitions.)
- An *object* is one piece of data plus its *metadata*, such as content type, size, and custom
  tags. You read or replace a whole object. You can't edit part of it in place.
- A *key* is the object's name, such as `uploads/2026/11/avatar-42.png`. S3 has no real folders:
  the slashes are just characters in the key. The console shows them as folders to make browsing
  easier. The first part of a key, such as `uploads/2026/`, is called a *prefix*.

Your application reads and writes objects over HTTPS, through the AWS CLI, an SDK, or the API.
This is the main trade-off. You give up in-place edits and a mounted folder. In return, any
server, container, or Lambda function can reach the same data, and you have no disk to manage.

![Diagram of the S3 bucket my-app-uploads holding three objects with the keys uploads/2026/11/avatar-42.png, uploads/2026/11/avatar-43.png, and backups/db-2026-11-27.sql.gz. The shared part uploads/2026/11/ is marked as a prefix, not a real folder. The object avatar-42.png is expanded into its key, its data (the bytes of the file, read or replaced whole), and its metadata (Content-Type: image/png, size, and custom tags).](/assets/images/posts/aws-why-use-s3/object-anatomy.svg)

## Why S3 Instead of a Disk

| | Disk on your server | Amazon S3 |
| --- | --- | --- |
| Capacity | Fixed; grow it by hand | No total limit; objects up to 50 TB each |
| Copies | One, unless you set up backups | Stored across multiple devices; designed for 99.999999999% (11 nines) durability |
| Shared by many servers | No | Yes, over HTTPS |
| Cost | You pay for the whole disk, used or not | You pay per GB stored, per request, and for data out |
| Edit in place | Yes | No: replace the whole object |

Two more behaviors matter when you write code against S3.

First, reads see the latest write. S3 has *strong read-after-write consistency*: after a write
succeeds, the next read or list request returns the new data. Some older guides warn about delays
before a new object appears. That stopped being true in December 2020.

Second, large files need *multipart upload*, which splits a file into parts and uploads them
separately. A single PUT request can upload up to 5 GB, and AWS suggests multipart upload for
objects larger than 100 MB. The AWS CLI command `aws s3 cp` switches to multipart upload for you.

## When S3 Is the Wrong Tool

S3 is not a file system and not a database. Choose the storage by how your application uses the
data:

| You need | Use |
| --- | --- |
| A boot disk or a database's data files, attached to one server | Amazon EBS (block storage) |
| A shared folder that many servers mount and edit in place | Amazon EFS, or [S3 Files](/aws-s3-files-mount-s3-bucket-as-file-system/) to mount a bucket as a file system |
| Files that apps read and write whole, from anywhere | Amazon S3 |
| Rows you query and update | A database (see [AWS Databases: How to Choose the Right One](/aws-database-types/)) |

## Three Common Ways to Use S3

### Uploads and downloads with presigned URLs

New buckets block public access by default. Keep it that way. To let a browser download or
upload a private object, your backend creates a *presigned URL*. This is a link that works for
one object, for a limited time. The backend signs it with its own AWS credentials, so the browser
needs no credentials of its own.

The following commands create a bucket, upload a file, and create a download link for it. Bucket
names must be unique, so replace `123456` with your own suffix.

```sh
aws s3 mb s3://my-app-uploads-123456
aws s3 cp avatar-42.png s3://my-app-uploads-123456/uploads/avatar-42.png
aws s3 presign s3://my-app-uploads-123456/uploads/avatar-42.png --expires-in 600
```

The last command prints a URL. Anyone who has that URL can download that one file for 10
minutes. The `--expires-in` value is in seconds, and the default is one hour. The bucket stays
private, and the file doesn't pass through your server.

`aws s3 presign` creates download links only. For uploads, your backend uses an SDK to create a
presigned PUT URL, and the browser sends the file directly to S3 with it.

### Static websites with CloudFront and a private bucket

Older tutorials, including the first version of this post, made the bucket public and turned on
the S3 *website endpoint*. Avoid this for a production site, for two reasons. You must turn off
Block Public Access, and the website endpoint doesn't support HTTPS.

Instead, keep the bucket private and put CloudFront in front of it with *origin access control*
(OAC). With OAC, only your CloudFront distribution can read the bucket. CloudFront adds HTTPS,
your own domain name, and caching at edge locations near your users.

### Backups with versioning and lifecycle rules

Copying files to a bucket doesn't protect you from overwrites or accidental deletes. Turn on
versioning before you start the backup job:

```sh
aws s3api put-bucket-versioning --bucket my-backups-123456 \
  --versioning-configuration Status=Enabled
aws s3 sync /var/backups/db s3://my-backups-123456/db/
```

The first command turns on *versioning*. When an object is overwritten or deleted, S3 keeps the
previous version. A bad backup or an accidental delete can't destroy the last good copy.

The second command uploads the backup folder. `aws s3 sync` copies only new and changed files, so
you can run it every night without uploading everything again.

Versioning has a cost: old versions stay in the bucket, and you pay to store them. Add a
*lifecycle rule* to control that. A lifecycle rule moves old backups to a cheaper storage class
after a number of days and deletes them after your retention period. On a versioned bucket, make
sure the rule also expires *noncurrent versions* (the old copies), or they stay forever. You can
create lifecycle rules in the console or with `aws s3api put-bucket-lifecycle-configuration`.

## Storage Classes: Pay for How Often You Read

Every object has a *storage class*. Classes for rarely read data cost less to store, but reading
the data back costs more or takes longer:

| Storage class | Use it for |
| --- | --- |
| S3 Standard (the default) | Data you read often |
| S3 Intelligent-Tiering | Data with unknown or changing access; S3 moves objects between tiers for a small monitoring fee, with no retrieval fees |
| S3 Standard-IA, S3 One Zone-IA | Data you read rarely but need right away (One Zone-IA keeps it in a single Availability Zone) |
| S3 Glacier Instant Retrieval, Flexible Retrieval, Deep Archive | Archives, from instant access to hours |
| S3 Express One Zone | The lowest latency, in one Availability Zone, for performance-critical workloads |

If you don't know the access pattern, start with Intelligent-Tiering.

## Why You No Longer Need Random Key Names

The first version of this post said to add random characters to the start of every key, so that
S3 would spread objects across partitions. That advice is out of date. S3 now supports at least
3,500 PUT/COPY/POST/DELETE requests and 11,000 GET/HEAD requests per second for each *partitioned
prefix*. It also adds partitions automatically as traffic grows.

A few habits still help:

- Spread very hot traffic across several prefixes. If one prefix needs more requests than those
  numbers, split it, for example into `logs/shard-1/` and `logs/shard-2/`. The prefixes can be
  readable names. They don't need to be random.
- Expect scaling to take time. When traffic to a quiet prefix jumps suddenly, some requests can
  fail with `503 Slow Down` while S3 scales. Retry with exponential backoff. The AWS SDKs retry
  these errors by default.
- Use multipart upload and parallel requests for large files.
- Put CloudFront in front of content that many users read, so repeated reads come from the cache
  instead of S3.

## Summary

- Object storage keeps whole objects in buckets and names them by keys. Folders are only key
  prefixes.
- S3 can replace the uploads folder on your server. You don't manage capacity, S3 is designed for
  11 nines of durability, and every server reaches the same data over HTTPS.
- S3 is not a disk or a file system. Use EBS for one server's disk, and EFS or S3 Files for a
  shared folder that you edit in place.
- Keep buckets private. Use presigned URLs for uploads and downloads, and CloudFront with origin
  access control for websites.
- For backups, turn on versioning and add lifecycle rules that also expire old versions. Choose
  storage classes by how often you read the data.
- You don't need random key names. S3 scales each prefix on its own.

Next step: find one place in your application that writes to the local disk, and list what it
would take to move that data to a private S3 bucket with presigned URLs.

## Resources

- [What is Amazon S3?](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html), Amazon S3 User Guide
- [Amazon S3 FAQs](https://aws.amazon.com/s3/faqs/), including limits and consistency
- [Best practices design patterns: optimizing Amazon S3 performance](https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance.html)
- [Understanding and managing Amazon S3 storage classes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html)
- [Blocking public access to your Amazon S3 storage](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)
