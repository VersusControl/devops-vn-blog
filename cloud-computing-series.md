---
layout: page
title: "Cloud Computing — A Complete Series"
permalink: /cloud-computing-series/
---

An introductory series on cloud computing — what the cloud is, its components
and characteristics, and the organizations that define cloud standards.

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "Cloud Computing" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> — {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>
