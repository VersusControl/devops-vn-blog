---
layout: page
title: "AWS CDK — A Complete Series"
permalink: /aws-cdk-series/
---

A hands-on series on the AWS Cloud Development Kit (CDK) — defining cloud
infrastructure in real programming languages, from the basics to constructs,
stacks, and building infrastructure for a real application.

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "AWS CDK" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> — {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>
