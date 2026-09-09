---
layout: page
title: "Docker Advanced - A Production Series"
permalink: /docker-advanced-series/
cover: /assets/images/series/docker-advanced-series.svg
---

Docker Basics got an application running. This series focuses on the work that follows: making images smaller, deploying them safely, securing the runtime, and diagnosing the failures that only show up once real traffic arrives.

## What you'll learn

- Build small, repeatable images with BuildKit and cache mounts
- Secure images, secrets, users, and container capabilities
- Publish multi-platform images and manage private registries
- Set CPU, memory, and filesystem limits for production workloads
- Use Compose profiles and production overrides
- Debug running containers and inspect their network traffic
- Build and publish images through CI/CD
- Move a Compose application to Kubernetes

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "Docker Advanced" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> - {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>
