---
layout: page
title: "Kubernetes Basics - From Container Image to Deployment"
permalink: /kubernetes-basics-series/
cover: /assets/images/series/kubernetes-basics-series.svg
---

Kubernetes manages applications that run as containers across one or more machines. This series starts with the control-plane concepts, creates a local cluster with Kind, packages a small API as an image, publishes it to GitHub Container Registry, and deploys it with Kubernetes resources.

## What you'll build

- A local Kubernetes cluster with Kind
- A small Node.js task API packaged as a container image
- A GitHub Container Registry image reference
- Pods, Deployments, Services, ConfigMaps, and Secrets
- A complete application deployment that can be inspected and updated with `kubectl`

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "Kubernetes Basics" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> - {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>
