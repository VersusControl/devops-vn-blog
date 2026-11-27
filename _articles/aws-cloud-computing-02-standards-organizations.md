---
layout: post
title: "Cloud Standards: Who Writes Them and Why They Matter"
subtitle: "Why standards decide how hard it is to move between clouds, the organizations behind them, and the open standards that do most of that work today."
series: "Cloud Computing"
series_url: /cloud-computing-series/
part: 2
date: 2026-11-28
author: Quan Huynh
tags: [cloud-computing, standards, portability, security, fundamentals]
image: /assets/images/posts/aws-cloud-computing-02-standards-organizations/cover.svg
---

A company runs on AWS for five years. Then a customer contract requires Azure, or a merger brings in
a team that runs everything on Google Cloud. Some workloads move in an afternoon. Others take a year
of rewriting. The size of the application rarely decides which. What decides it is how much of the
application uses open standards, and how much depends on one provider's own APIs.

Chapters [0](/aws-cloud-computing-00-what-is-cloud/) and
[1](/aws-cloud-computing-01-components-characteristics/) explained what a cloud is and how it works.
This chapter is about using more than one cloud, or moving from one to another. (Chapter 0 called
the first case multi-cloud.) By the end you will be able to:

- explain the three things cloud standards try to protect: interoperability, portability, and
  security;
- name the main organizations that write cloud standards, and what each is known for;
- recognize the open standards that make an application portable today, and where lock-in usually
  comes from.

## What Standards Are For

A *standard* is a published agreement on how something works: a file format, an API, or a set of
security controls. When providers and tools follow the same standard, things built for one work
with the others. Cloud standards aim at three goals.

### Interoperability: systems can work together

*Interoperability* means systems from different providers can exchange data and call each other.
For example, an application in your data center reads files from cloud storage, or a monitoring tool
collects data from three clouds at once. It depends on shared interfaces: the same API, protocol, or
data format on both sides.

### Portability: things can move

*Portability* means you can take an application or its data from one environment and run it in
another with few changes. A container image that runs on any Kubernetes cluster is portable. A
function written against one provider's event format, using that provider's database API, is not.

### Security: you can compare and trust

Security standards give everyone the same list of controls to check. Instead of every customer
writing its own questionnaire for every provider, a provider can show which controls in a shared
framework it meets, and customers can compare providers on the same terms. This matters because of
the shared responsibility model from Chapter 1: you can't inspect the provider's data centers
yourself, so you need evidence that the provider handles its part.

![Three goals of cloud standards: interoperability, where one monitoring tool collects data from AWS, Azure, and Google Cloud; portability, where one OCI container image runs on a Kubernetes cluster in any of the three; and security, where the same CSA Cloud Controls Matrix is checked against each provider](/assets/images/posts/aws-cloud-computing-02-standards-organizations/three-goals.svg)

## The Organizations Behind Cloud Standards

| Organization | What it is | Known for |
| --- | --- | --- |
| NIST (US National Institute of Standards and Technology) | A US government standards agency | SP 800-145, the definition of cloud computing used in this series |
| ISO/IEC JTC 1/SC 38 | The international committee of ISO and IEC for cloud computing and distributed platforms | International cloud vocabulary and reference architecture standards |
| Cloud Security Alliance (CSA) | A non-profit focused on cloud security | The Cloud Controls Matrix (CCM), a security control framework now at version 4.1, and the STAR registry where providers publish their assessments |
| DMTF | An industry group for IT management standards | The Open Virtualization Format (OVF) for packaging virtual machines |
| SNIA (Storage Networking Industry Association) | An industry group for storage | The Cloud Data Management Interface (CDMI) for managing data in cloud storage |
| Open Grid Forum (OGF) | A community for distributed computing standards | The Open Cloud Computing Interface (OCCI) for managing cloud resources |
| Linux Foundation, through the Open Container Initiative (OCI) and the Cloud Native Computing Foundation (CNCF) | A non-profit that hosts open-source projects | Container image and runtime specifications (OCI), and Kubernetes and OpenTelemetry (CNCF) |

The first six publish formal standards or frameworks. The last row is different: it hosts
open-source projects that became de facto standards because almost everyone adopted them.

## The Standards That Do the Work Today

Formal standards like OVF, CDMI, and OCCI shaped the early cloud. In daily work today, most
portability comes from a few open specifications and open-source projects:

- **OCI container images.** The Open Container Initiative, launched in 2015 under the Linux
  Foundation, publishes three specifications: the image format, how images are distributed through
  a registry, and how a container runs. An image built on your laptop runs on Amazon ECS, Azure
  Container Apps, Google Cloud Run, or any Kubernetes cluster, because they all follow the OCI image
  format. (The image must still match the CPU architecture of the machine that runs it. An image
  built on an Apple silicon laptop is arm64 by default and won't start on x86 servers unless you
  also build it for x86.)
- **Kubernetes.** The same Kubernetes manifests deploy to Amazon EKS, Azure Kubernetes Service, Google
  Kubernetes Engine, or a cluster in your own data center. Each provider adds its own extras, such as
  load balancer annotations and storage classes, but the core API is the same.
- **The S3 API.** Amazon S3's API became the common language for object storage. Many other storage
  products accept S3 API calls, so tools written for S3 often work with them unchanged.
- **OpenTelemetry.** A CNCF project and open standard for traces, metrics, and logs. Instrument your
  application once, and send the data to any backend that accepts it, instead of using one
  provider's monitoring agent.

## Where Lock-In Comes From

*Vendor lock-in* means moving to another provider costs so much that you can't realistically do it.
It rarely comes from the basic building blocks; virtual machines, containers, and object storage move
fairly easily. It comes from the services that have no standard equivalent:

- provider-specific databases and their APIs, such as DynamoDB, Cosmos DB, or Spanner;
- event formats and triggers wired between serverless services;
- identity and permission systems (AWS IAM, Microsoft Entra ID, Google Cloud IAM), which are
  designed differently;
- infrastructure-as-code written in a provider-only tool.

Lock-in isn't always bad. A managed service that saves your team months of work is often worth it.
The point is to choose it knowingly: use open standards where they cost you little (containers,
OpenTelemetry, open-source databases like PostgreSQL), and accept provider-specific services where they
clearly pay for themselves.

## Summary

- Cloud standards protect interoperability (systems work together), portability (things can move),
  and security (controls can be compared).
- NIST defined cloud computing; ISO/IEC JTC 1/SC 38 writes international cloud standards; CSA's Cloud
  Controls Matrix is the common security framework; DMTF, SNIA, and OGF wrote OVF, CDMI, and OCCI.
- Today most portability comes from OCI container images, Kubernetes, the S3 API, and OpenTelemetry.
- Lock-in comes from provider-specific databases, event wiring, identity systems, and tooling. Choose
  it on purpose, where it saves real work.

That's the end of the series. You now have the vocabulary behind every cloud: the definition and
deployment models, the layers and service models, and the standards that connect clouds. A good
next step is to pick one provider and build something small on it, checking each piece against the
five essential characteristics from [Chapter 1](/aws-cloud-computing-01-components-characteristics/).

## Resources

- [NIST SP 800-145: The NIST Definition of Cloud Computing](https://csrc.nist.gov/pubs/sp/800/145/final)
- [Cloud Controls Matrix (CCM)](https://cloudsecurityalliance.org/research/cloud-controls-matrix), Cloud Security Alliance
- [Open Container Initiative](https://opencontainers.org/about/overview/)
- [OpenTelemetry](https://opentelemetry.io/)
