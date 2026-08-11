---
layout: page
title: "Docker Basics — A Complete Series"
permalink: /docker-series/
cover: /assets/images/series/docker-series.svg
---

A beginner-friendly series on **Docker** — the industry standard for containerization. We start
from scratch: what containers are, why they matter, and how to install Docker. Then we build up
step by step — writing Dockerfiles, networking containers, persisting data with volumes, and
orchestrating multi-container applications with Docker Compose. By the end you'll have built
a complete **Task App** (Node.js API + Python worker + PostgreSQL + Redis) and be ready to
containerize anything you work on.

## What you'll learn

- Understand what containers are and how they differ from virtual machines
- Install Docker and run your first container
- Write Dockerfiles with multi-stage builds and best practices
- Manage containers: logs, exec, resource limits
- Connect containers with Docker networking
- Persist data with volumes and bind mounts
- Orchestrate multi-container apps with Docker Compose
- Apply production-ready patterns and security practices

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "Docker Basics" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> — {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>
