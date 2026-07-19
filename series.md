---
layout: page
title: "Series"
permalink: /series/
---

Deep-dive, multi-part guides — each series takes a topic from the ground up. Pick
a series below and follow it chapter by chapter.

<div class="series-index">
{% for s in site.data.series %}
  {% assign posts = site.articles | where: "series", s.key | sort: "part" %}
  <section class="series-index-card">
    <div class="series-index-head">
      {% if s.category %}<span class="series-index-eyebrow">{{ s.category }}</span>{% endif %}
      <h2 class="series-index-title"><a href="{{ s.url | relative_url }}">{{ s.title }}</a></h2>
      <p class="series-index-blurb">{{ s.blurb }}</p>
      <div class="series-index-meta">
        <span class="series-index-count">{{ posts | size }} chapter{% if posts.size != 1 %}s{% endif %}</span>
        <a class="series-index-link" href="{{ s.url | relative_url }}">Open series →</a>
      </div>
    </div>
    <details class="series-index-details">
      <summary>View chapters</summary>
      <ul class="series-list">
      {% for p in posts %}
        <li>{% if p.part %}<span class="series-chapter">Chapter {{ p.part }}</span> — {% endif %}<a href="{{ p.url | relative_url }}">{{ p.title }}</a></li>
      {% endfor %}
      </ul>
    </details>
  </section>
{% endfor %}
</div>
