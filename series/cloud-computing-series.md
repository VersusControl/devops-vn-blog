---
layout: page
title: "Cloud Computing: The Ideas Under Every Cloud"
permalink: /cloud-computing-series/
cover: /assets/images/series/cloud-computing-series.svg
---

"Cloud" is one of the most used words in tech, and one of the least explained. This short series
steps away from any one provider and explains what sits underneath AWS, Azure, and Google Cloud:
what cloud computing is, how a cloud is built, and how different clouds work together.

It's written for engineers starting out with the cloud, and for anyone who uses a cloud every day
but never had the concepts laid out in order. The series builds on NIST SP 800-145, the definition
of cloud computing the industry still uses, with examples from AWS and the other big providers. (The first version of this series drew on the book *Cloud Computing For Dummies*.)

## What You'll Learn

- What cloud computing is, in one precise definition, and the four deployment models: public,
  private, community, and hybrid, plus where multi-cloud fits.
- How a cloud works inside: the shared resource pool, the three service models (IaaS, PaaS, SaaS)
  and what you're responsible for in each, and the five essential characteristics every cloud has.
- Why standards matter when you use more than one cloud, who writes them, and which open standards
  make an application portable today.

## Series

<ul class="series-list">
{% assign posts = site.articles | where: "series", "Cloud Computing" | sort: "part" %}
{% for p in posts %}
  <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> — {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
{% endfor %}
</ul>

