---
layout: page
title: "ArgoCD — A Complete Series"
permalink: /argocd-series/
---

A step-by-step series on using Argo CD for GitOps continuous delivery on
Kubernetes — deploying and managing the Book Info microservices application.

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "ArgoCD" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> — {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>
