---
layout: post
title: "How a Cloud Works: Resource Pools, Service Models, and Five Characteristics"
subtitle: "What sits under every cloud: a shared resource pool, three ways to rent it (IaaS, PaaS, SaaS), and the five characteristics that make it a cloud and not just a data center."
series: "Cloud Computing"
series_url: /cloud-computing-series/
part: 1
date: 2026-11-28
author: Quan Huynh
tags: [cloud-computing, aws, iaas, paas, saas, fundamentals]
image: /assets/images/posts/aws-cloud-computing-01-components-characteristics/cover.svg
---

Two teams deploy the same Node.js website. The first creates a virtual machine, installs Node.js,
configures Nginx, sets up a firewall, and patches the operating system every month. The second
uploads the code to a managed platform and gets a URL back. Both are "using the cloud", but they
rented very different things, and they carry very different amounts of work.

In [Chapter 0](/aws-cloud-computing-00-what-is-cloud/) we defined cloud computing and its four
deployment models. This chapter opens the cloud up and looks at the layers inside it. By the end you
will be able to:

- explain the shared resource pool that every cloud is built on;
- choose between IaaS, PaaS, and SaaS, and say what you're responsible for in each;
- name the five characteristics that make something a cloud, and recognize them on AWS.

## The Layers of a Cloud

NIST doesn't describe a cloud in layers, but layers are a useful way to picture what's inside one.
This chapter uses four, from the bottom up:

1. **The resource pool:** physical servers, storage, and networks, shared by many customers.
2. **The service models:** what the provider rents out from that pool: infrastructure, a platform,
   or finished software.
3. **The foundational services:** what makes renting possible: self-service, network access,
   elastic scaling, and measuring usage for the bill.
4. **The management services:** what every customer needs on top: security, monitoring, data
   management, and integration.

The rest of the chapter walks up the stack one layer at a time.

![A cloud as four stacked layers, from the bottom up: a resource pool of servers, storage, and networks shared by many tenants; service models IaaS, PaaS, and SaaS; foundational services for self-service, network access, elasticity, and metering and billing; and management services for security, monitoring, data management, and integration](/assets/images/posts/aws-cloud-computing-01-components-characteristics/cloud-layers.svg)

## The Resource Pool and Multi-Tenancy

At the bottom is a large pool of hardware. The provider doesn't give each customer their own
machines. Instead, *virtualization* splits physical servers into many virtual ones, and those are
handed out to whoever asks.

Sharing one pool between many customers is called *multi-tenancy*. Each customer is a *tenant*. The
cloud keeps every tenant's resources and data isolated, so you can't see your neighbor's virtual
machines or files, even when they run on the same physical server. The same idea applies to
software: a SaaS provider usually runs one copy of its application for all tenants, instead of a
separate installation per customer.

Multi-tenancy is what makes the cloud cheaper and faster than buying your own hardware. The provider
buys hardware in bulk, keeps it busy, and hands out a new server from capacity that already exists.
It's also why isolation between tenants is the provider's first security responsibility.

## Three Ways to Rent It: IaaS, PaaS, and SaaS

The service model decides how much of the stack you rent ready-made, and how much you run yourself.

| | IaaS | PaaS | SaaS |
| --- | --- | --- | --- |
| You get | Virtual machines, disks, networks | A platform that runs your code | A finished application |
| You manage | Operating system, runtime, application, data | Your application and data | Your data and your users |
| The provider manages | Hardware, virtualization | Hardware, virtualization, OS, runtime, and usually scaling | Everything else |
| AWS examples | Amazon EC2, Amazon EBS, Amazon VPC | AWS Elastic Beanstalk, AWS Lambda | Amazon Connect (contact center) |
| Other examples | Azure Virtual Machines, Compute Engine | Azure App Service, Google App Engine | Microsoft 365, Jira Cloud |

### Infrastructure as a Service (IaaS)

You rent the building blocks of a data center: virtual machines, disks, and networks. You choose the
operating system and install everything on top. This is the first team in the opening example. It
gives the most control, and the most work: patching, scaling, and backups are yours.

### Platform as a Service (PaaS)

You bring your code, and the platform runs it. The provider installs and patches the operating
system and runtime, and usually scales the application for you. On AWS, Elastic Beanstalk can take a
Node.js application and create the servers, load balancer, and scaling rules for it. AWS Lambda goes
further: you upload a function, and there are no servers to see at all. This is the second team in
the opening example.

### Software as a Service (SaaS)

You use an application that someone else builds and runs, and you pay per user or per month. Your
email, your issue tracker, and your video calls are probably SaaS. You manage only your data and who
has access.

### Choosing between them

Start from the top: if SaaS solves the problem, don't build it. If you're building, start with PaaS
and move down to IaaS only when you need control the platform doesn't give you: a specific operating
system or kernel setting, special hardware, or a process that runs longer than the platform allows.

The further down you go, the more of the *shared responsibility* is yours. On AWS, the
[shared responsibility model](https://aws.amazon.com/compliance/shared-responsibility-model/) puts
it this way: AWS is responsible for security *of* the cloud (the hardware and facilities), and you
are responsible for security *in* the cloud (your data, access, and configuration). With IaaS, "in
the cloud" includes the operating system. With PaaS and SaaS, it shrinks.

## The Five Characteristics of a Cloud

The foundational services layer is how a provider delivers what NIST calls the five *essential
characteristics*. Chapter 0 mentioned them; this section explains each one. If a service is missing one,
it isn't really a cloud, even if it runs in a modern data center.

| Characteristic | What it means | What it looks like on AWS |
| --- | --- | --- |
| On-demand self-service | You get resources yourself, without asking a person | Launching an EC2 instance from the console or with `aws ec2 run-instances` |
| Broad network access | You use the cloud over the network, from standard clients | The web console, the AWS CLI, SDKs, and the API over HTTPS |
| Resource pooling | Many tenants share one pool; you don't know or control which machine you're on | Your instance runs somewhere in an Availability Zone you picked |
| Rapid elasticity | You can add and remove capacity quickly, often automatically | An Auto Scaling group adding instances when traffic rises |
| Measured service | Usage is measured, reported, and billed | Per-second billing for EC2, and Cost Explorer showing what you spent |

Two of these change how teams work the most.

On-demand self-service replaces the ticket-and-wait process from the opening of Chapter 0. A
developer can create a test environment in minutes and delete it the same afternoon. In a
traditional data center, the same request could take days or weeks of approvals and installation.

Measured service is what makes pay-as-you-go possible. Because the provider measures every
resource, it can bill you only for what you use, while you use it. When you delete a resource, it
returns to the pool for another tenant, and its billing stops. The other side of this is a common
first surprise on a cloud bill: a test server or disk that nobody deleted keeps billing every hour
until someone notices. So cost monitoring becomes part of the job.

## Management Services: What Every Customer Needs

At the top are the services every customer needs, whichever provider they choose:

- **Security:** identity and access management, encryption, and network isolation. On AWS, that's
  IAM, KMS, and VPC security groups.
- **Monitoring:** knowing whether your resources are healthy, and getting alerts when they aren't.
  On AWS, Amazon CloudWatch.
- **Data management:** backups, replication, and where data is stored.
- **Integration:** connecting cloud resources to each other and to systems outside the cloud.

Once your first application is running, most day-to-day cloud work happens in this layer.

## Summary

- Every cloud sits on a shared resource pool. Multi-tenancy lets many customers share it, while each
  one's resources and data stay isolated.
- The service model decides what you rent: IaaS (machines), PaaS (a platform for your code), or SaaS
  (a finished application). The higher you go, the less you manage.
- Under the shared responsibility model, the provider secures the cloud itself, and you secure what
  you put in it.
- NIST's five essential characteristics (on-demand self-service, broad network access, resource
  pooling, rapid elasticity, and measured service) are what make it a cloud.
- Security, monitoring, data management, and integration are the management layer every customer
  needs.

Next: [Chapter 2](/aws-cloud-computing-02-standards-organizations/) covers what happens when you
use more than one cloud: the standards that let applications and data move between them, and the
organizations that write those standards.

## Resources

- [NIST SP 800-145: The NIST Definition of Cloud Computing](https://csrc.nist.gov/pubs/sp/800/145/final)
- [AWS Shared Responsibility Model](https://aws.amazon.com/compliance/shared-responsibility-model/)
- [Types of cloud computing](https://aws.amazon.com/types-of-cloud-computing/), AWS
