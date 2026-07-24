---
layout: page
title: "Cloud Computing — A Complete Series"
permalink: /cloud-computing-series/
cover: /assets/images/series/cloud-computing-series.svg
---

"Cloud" is one of the most-used words in tech — but what actually sits underneath it?
This series steps away from any single provider and focuses on the ideas that make the
cloud work: what cloud computing really means, the building blocks every cloud is made
of, the characteristics that set it apart from a traditional data center, and the
standards bodies that keep the whole ecosystem interoperable.

It's a beginner-friendly foundation. Whether you're about to learn AWS, Azure, or GCP,
these concepts carry across all of them — so you understand *why* the cloud behaves the
way it does, not just which buttons to click. The series draws on the book *Cloud
Computing For Dummies*.

## What You'll Learn

- What cloud computing and "the cloud" actually are, and the deployment models
  (public, private, hybrid, and multi-cloud)
- The core components of a cloud — resource pools, delivery models (IaaS, PaaS, SaaS),
  and its foundational and management services
- The characteristics that define a cloud, from billing and self-service provisioning
  to security and monitoring
- The organizations that build cloud standards and why those standards matter

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "Cloud Computing" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> — {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>

