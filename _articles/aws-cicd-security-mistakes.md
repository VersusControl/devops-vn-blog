---
layout: post
title: "Security Mistakes in AWS CI/CD That You Might Overlook"
date: 2023-11-11
author: Quan Huynh
tags: [aws, ci-cd, security]
image: /assets/images/posts/aws-cicd-security-mistakes/cover.png
---

When we build a CI/CD flow with AWS services — EC2, for example — we often SSH
into the EC2 instance and run commands. Or, when working with AWS S3, we often
use the AWS CLI to download files from S3. For the AWS CLI to work, we have to
configure the AWS keys, and I've noticed people often put them directly into the
CI/CD file. It may look fine, but it's a very serious security issue.

## The Problem

For example, look at the following CodeBuild `buildspec.yaml`:

![Insecure buildspec.yaml]({{ '/assets/images/posts/aws-cicd-security-mistakes/buildspec.png' | relative_url }})

There are many security issues in the `buildspec.yaml` code above:

- First, the AWS key is placed directly in the file.
- Second, the DB information is in plain text.
- Third, you use `scp` to transfer the DB password config file over the Internet.
- Fourth, in this file you can expose the SSH key, IP, and user of the server.

I think quite a few beginners commonly make one of the mistakes above.

## The Solution

To make the `buildspec.yaml` file more secure, you can use the following
approaches:

- First, attach an IAM Role to CodeBuild instead of putting the AWS key in the
  `buildspec.yaml` file. If you use GitLab CI or Jenkins, use AWS STS.
- Second, use Parameter Store or AWS Secrets Manager to hold the DB information.
- Third and fourth, instead of using `scp` and `ssh`, use AWS Systems Manager Run
  Command.
