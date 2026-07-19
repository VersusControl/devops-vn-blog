---
layout: post
title: "Improve Application Load Balancer Network Performance with CloudFront"
date: 2024-09-24
author: Quan Huynh
tags: [aws, cloudfront, performance]
image: /assets/images/posts/aws-alb-cloudfront-performance/cover.png
---

> Main point: use an Application Load Balancer (ALB) **with** CloudFront rather than
> using ALB alone.

## Reduced Latency

CloudFront delivers content from edge locations closer to users and uses the AWS
backbone network from the edge to the ALB.

ALB without CloudFront: load time ≈ 750ms

![ALB without CloudFront latency]({{ '/assets/images/posts/aws-alb-cloudfront-performance/alb-latency.png' | relative_url }})

ALB with CloudFront: load time ≈ 440ms

![ALB with CloudFront latency]({{ '/assets/images/posts/aws-alb-cloudfront-performance/alb-cloudfront-latency.png' | relative_url }})

## Connection Optimization

CloudFront supports TLS 1.3.

![TLS 1.3]({{ '/assets/images/posts/aws-alb-cloudfront-performance/tls13.png' | relative_url }})

CloudFront maintains persistent connections to the ALB, which minimizes the
overhead of establishing new TCP connections for each request.

ALB without CloudFront:

![ALB without CloudFront connection]({{ '/assets/images/posts/aws-alb-cloudfront-performance/alb-connection.png' | relative_url }})

ALB with CloudFront reduces the initial connection: **278.8ms → 17.5ms**

![ALB with CloudFront connection]({{ '/assets/images/posts/aws-alb-cloudfront-performance/alb-cloudfront-connection.png' | relative_url }})
