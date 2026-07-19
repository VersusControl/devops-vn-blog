---
layout: page
title: Tags
permalink: /tags/
---

<p>Browse all posts by tag.</p>

{% assign all_tags = "" | split: "" %}
{% for post in site.articles %}{% for tag in post.tags %}{% unless all_tags contains tag %}{% assign all_tags = all_tags | push: tag %}{% endunless %}{% endfor %}{% endfor %}
{% assign all_tags = all_tags | sort %}

<div class="tag-cloud">{% for tag in all_tags %}<a class="tag-chip" href="#{{ tag }}">{{ tag }}</a>{% endfor %}</div>

{% for tag in all_tags %}
<section class="topic-section" id="{{ tag }}">
<h2>{{ tag }}</h2>
{% assign posts = site.articles | where_exp: "post", "post.tags contains tag" | sort: "date" | reverse %}
<div class="topic-cards">{% for post in posts %}<a class="topic-card" href="{{ post.url | relative_url }}">{% if post.image %}<div class="topic-card-image"><img src="{{ post.image | relative_url }}" alt="{{ post.title }}" loading="lazy"></div>{% else %}<div class="topic-card-image topic-card-placeholder"></div>{% endif %}<div class="topic-card-body"><time class="topic-card-date">{{ post.date | date: "%b %d, %Y" }}</time><h3 class="topic-card-title">{{ post.title }}</h3></div></a>{% endfor %}</div>
</section>
{% endfor %}
