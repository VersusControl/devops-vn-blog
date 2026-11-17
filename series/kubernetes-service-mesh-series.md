---
layout: page
title: "Kubernetes Advanced: Service Mesh - Istio by Practice"
permalink: /kubernetes-service-mesh-series/
cover: /assets/images/series/kubernetes-service-mesh-series.svg
---

A service mesh manages the traffic between services in a Kubernetes cluster: routing, retries, encryption, access rules, and telemetry, without changes to application code. This series runs Istio 1.32 on a local Kind cluster with Book Store, an example app built from Istio's Bookinfo images and deployed with the series' own manifests.

Each chapter starts from a problem the Book Store team hits, explains the concept behind the fix, applies it step by step, and then breaks it on purpose so you can diagnose and fix the failure. By the end you can deploy and run Istio in your own environment.

## What you'll learn

- What a service mesh solves, and when it is worth the cost
- Install Istio on Kind and add workloads to the mesh
- Expose applications through an Istio ingress gateway with TLS, redirects, and several hosts
- Debug a gateway from the YAML you applied down to the Envoy configuration
- Release new versions with subsets, weighted routing, and header-based routing
- Use timeouts, retries, fault injection, circuit breaking, and outlier detection
- Control traffic that leaves the mesh with ServiceEntry and an egress gateway
- Secure service-to-service traffic with mutual TLS, authorization policies, and JWT
- Observe the mesh with metrics, tracing, and Kiali
- Use the Kubernetes Gateway API with Istio
- Install and upgrade Istio in your own environment with Helm and revisions

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "Kubernetes Advanced: Service Mesh" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> - {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>
