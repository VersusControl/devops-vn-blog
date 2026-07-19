---
layout: post
title: "What Is the Cloud?"
series: "Cloud Computing"
series_url: /cloud-computing-series/
part: 0
date: 2022-12-28
author: Quan Huynh
tags: [aws, cloud-computing]
image: /assets/images/posts/aws-cloud-computing-00-what-is-cloud/cover.png
---

Welcome to the Cloud Computing series. In this series we won't focus on how to
use any specific cloud provider — instead, we'll explore the technology that
sits underneath the cloud.

This series is based on the book *Cloud Computing For Dummies*.

"Cloud" is a term you've heard a lot in recent years. It has completely changed
the way businesses operate and deploy software. So what is the cloud? Before we
can understand what the cloud is, we first need to understand the concept of
cloud computing.

## Cloud Computing

Cloud computing is a way of delivering computing resources to users as easily as
possible — including applications, software, hardware, storage, networking, and
more.

With cloud computing, everything from infrastructure to applications can be
delivered to users as a service over the Internet.

## The Cloud

The cloud is a collection of many computing resources — hardware, networking,
storage, and software applications — hosted on servers distributed all over the
world. These servers all use cloud computing technology so that, as long as a
user has an Internet connection, they can easily access any resource.

The cloud is deployed using different models.

## Cloud Deployment Models

The cloud has two main models: **Public Cloud** and **Private Cloud**.

![Public and Private Cloud models]({{ '/assets/images/posts/aws-cloud-computing-00-what-is-cloud/cloud-models.png' | relative_url }})

From these two models we get two additional sub-models: **Hybrid Cloud** and
**Multi-cloud**.

Hybrid Cloud is an environment that combines Public Cloud and Private Cloud
together with data centers.

Multi-cloud is an environment that combines multiple public clouds.

## Public Cloud

Public Cloud is a model whose resources can be used by anyone. It's the most
common model today because, in addition to providing computing resources, a
public cloud also offers a huge number of accompanying services and applications
that make deploying software faster and faster.

One example of a public cloud is AWS. With AWS, deploying an application is very
fast. For instance, when you need Redis, you don't have to install anything —
AWS provides the Elasticache service, and with a few simple steps you have Redis
ready to use.

Most public cloud providers give users a Web Console and an API so they can
easily access the cloud's resources.

## Private Cloud

Private Cloud is a model whose resources are provisioned exclusively for a
business, or for its employees and partners. A private cloud is an environment
that requires a high level of security, so it's usually placed behind a firewall
and not everyone can access it. A private cloud is typically developed and
managed directly by the business that uses it.

You can simply think of a private cloud as a company's own data center that uses
cloud computing technology.

One example of a private cloud is FPT Cloud — FPT built a cloud for its own
business and employees to use.

Building your own cloud environment is not easy. Today, however, that problem has
been largely solved.

## Running a Public Cloud on Your Data Center

These days, public cloud providers package their cloud services into
applications that can be installed on a company's own data center (on-premises)
environment.

![Public cloud on a data center]({{ '/assets/images/posts/aws-cloud-computing-00-what-is-cloud/public-cloud-on-datacenter.png' | relative_url }})

This lets businesses use public cloud services easily while still maintaining
security, because their data and applications all run on their own data center.

## Conclusion

We've now covered the concepts of cloud computing and the cloud. The cloud is the
future of the tech industry, and we should learn it to avoid falling behind. I
recommend learning AWS, as it's the most popular cloud today. In the next post,
we'll look at the concepts of Resource Pools and Cloud Models.
