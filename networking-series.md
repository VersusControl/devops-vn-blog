---
layout: page
title: "Networking for DevOps — A Complete Series"
permalink: /networking-series/
cover: /assets/images/series/networking-series.svg
---

A practical networking series for DevOps engineers — the essential concepts you
need day to day, from the OSI model and protocols to subnetting, routing, DNS,
VPNs, and Linux networking tools.

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "Networking for DevOps" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> — {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>
