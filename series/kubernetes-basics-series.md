---
layout: page
title: "Kubernetes Basics — A Complete Series"
permalink: /kubernetes-basics-series/
cover: /assets/images/series/kubernetes-basics-series.svg
---

A beginner-friendly series on Kubernetes fundamentals — from what Kubernetes is
to Pods, labels, replication controllers, ReplicaSets, and DaemonSets.

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "Kubernetes Basics" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> — {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>
