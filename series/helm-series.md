---
layout: page
title: "Helm — A Complete Series"
permalink: /helm-series/
cover: /assets/images/series/helm-series.svg
---

A beginner-friendly series on **Helm 4**, the package manager for Kubernetes. We start
from the very basics — what Helm is and why you need it — and build up step by step to
packaging and shipping a real application (the **Book Info** microservices) as your own
Helm chart. By the end you'll be comfortable templating charts, managing values across
environments, handling dependencies, and rolling out upgrades safely.

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "Helm" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> — {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>
