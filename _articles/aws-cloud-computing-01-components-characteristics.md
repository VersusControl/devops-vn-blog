---
layout: post
title: "Components and Characteristics of the Cloud"
series: "Cloud Computing"
series_url: /cloud-computing-series/
part: 1
date: 2023-01-09
author: Quan Huynh
tags: [aws, cloud-computing]
image: /assets/images/posts/aws-cloud-computing-01-components-characteristics/cover.png
---

In the previous post we learned what cloud computing and the cloud are. In this
post we'll look at the basic components and characteristics that a cloud must
have.

## Components of the Cloud

The diagram below shows the main components of the cloud.

![Main cloud components]({{ '/assets/images/posts/aws-cloud-computing-01-components-characteristics/cloud-components.png' | relative_url }})

There are four parts:

- Resource Pools
- Cloud Models
- Foundational Service Elements
- Management Services

We'll work from the bottom up, starting with Resource Pools.

> Note: I'll keep the technical terms in their original English form.

## Resource Pools

A Resource Pool is where shareable resources live — it's the most fundamental
component of the cloud.

Resource Pools are designed around a **multi-tenant** service architecture, a
style of architecture that lets many users share the same computing resources
while keeping each user's configuration and data isolated so that only they can
access it.

![Multi-tenant resource pools]({{ '/assets/images/posts/aws-cloud-computing-01-components-characteristics/resource-pools.png' | relative_url }})

With a multi-tenant architecture, cloud providers don't need to copy their
software for each individual user. Instead, all users share the same software to
access cloud resources while still keeping their data independent from other
users.

From these Resource Pools, cloud providers distribute their services through
different models, called **Cloud Delivery Models**.

## Cloud Delivery Models

The common delivery models are:

- Infrastructure as a Service
- Platform as a Service
- Software as a Service

### Infrastructure as a Service (IaaS)

IaaS is a service model that provides infrastructure and computing resources to
users over the Internet. As long as they have Internet access, they can request
resources to use.

With a public cloud, a user simply needs a credit card and an Internet
connection — from anywhere, they can request resources from the cloud, and when
they no longer need them, they just turn the service off.

With a private cloud, users request resources from the company's IT department
based on company policy.

### Platform as a Service (PaaS)

PaaS is a model that combines IaaS with a set of ready-made software services so
users can deploy their applications as quickly as possible.

For example, on AWS, deploying a website with Node.js normally requires you to:

- Create an EC2 instance
- Access the EC2 instance and install Node.js- or Docker-related software
- Configure a web service such as Nginx and do many other things to get Node.js
  running

AWS provides a PaaS service called Elastic Beanstalk that has everything ready —
with just a few simple actions in the Web Console, you get a website running
Node.js.

The simplest way to explain PaaS: it's IaaS where all the necessary software is
already in place.

### Software as a Service (SaaS)

Software as a Service delivers software to users, and users pay monthly or yearly
to use it — for example Jira Cloud, OneDrive, Terraform Cloud, and so on.

SaaS is considered the future of the software industry.

From these Cloud Delivery Models, providers build the characteristics a cloud
must have to serve users. These are split into Foundational Services and
Management Services.

## Foundational Service Elements

![Foundational service elements]({{ '/assets/images/posts/aws-cloud-computing-01-components-characteristics/foundational-services.png' | relative_url }})

Let's go through two characteristics: Billing and Self-Service Provisioning.

### Billing

This is a very important characteristic of the public cloud. Users consume
computing resources when they want, and are only charged for the resources they
actually use and the time they use them.

To meet this requirement, a cloud provider has to design a platform that fulfills
a user's resource request immediately and starts billing. When the user stops
using a resource, that resource is returned to the Resource Pool so other users
can use it, and billing stops.

### Self-Service Provisioning

This is the next important cloud characteristic. With self-service provisioning,
users can use the provider's website to select and use the service they want in
just a few minutes.

For example, on AWS, if you need a virtual machine, you log into the AWS Web
Console and create an EC2 instance to run it.

With a traditional data center model, when you need a virtual machine the first
thing you do is file a request with IT. After going through complex procedures
and payments, your request is approved. Then you wait for IT to configure the
hardware, software, and related applications. This process can take days or
weeks. With the cloud, it takes just a few minutes.

## Management Services

![Management services]({{ '/assets/images/posts/aws-cloud-computing-01-components-characteristics/management-services.png' | relative_url }})

The highest layer of cloud architecture consists of the characteristics that
address the basic needs users care about regardless of which cloud provider they
use, including: Security, Service Monitoring, Data Management, and Integration.

Security is always a critical characteristic because users always require their
applications and data to be protected.

Service Monitoring gives users built-in monitoring services so they know what's
happening with their applications.

Data Management lets users move their data between different cloud providers and
data centers.

Finally, Integration: the cloud must provide services that help users connect
clouds to each other and to data centers, so they can build Hybrid Cloud or
Multi-cloud models.

## Conclusion

We've now covered the basic components and characteristics a cloud must have. In
the next posts we'll talk about the standards and how to manage a cloud
environment.
