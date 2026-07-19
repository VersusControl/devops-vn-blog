---
layout: page
title: Topics
permalink: /topics/
---

<div class="topic-tabs" role="tablist">
  <button class="topic-tab active" data-target="terraform">Terraform</button>
  <button class="topic-tab" data-target="kubernetes">Kubernetes</button>
  <button class="topic-tab" data-target="aws">AWS</button>
  <button class="topic-tab" data-target="azure">Azure</button>
  <button class="topic-tab" data-target="prometheus">Prometheus</button>
  <button class="topic-tab" data-target="service-mesh">Service Mesh</button>
  <button class="topic-tab" data-target="networking">Networking</button>
  <button class="topic-tab" data-target="linux">Linux Tips</button>
  <button class="topic-tab" data-target="devops">DevOps</button>
</div>

<script>
document.addEventListener('DOMContentLoaded', function () {
  var tabs = document.querySelectorAll('.topic-tab');
  var panels = document.querySelectorAll('.topic-panel');
  if (!tabs.length || !panels.length) return;
  function activate(id) {
    tabs.forEach(function (t) { t.classList.toggle('active', t.dataset.target === id); });
    panels.forEach(function (p) { p.classList.toggle('active', p.id === id); });
  }
  tabs.forEach(function (t) {
    t.addEventListener('click', function () {
      activate(t.dataset.target);
      history.replaceState(null, '', '#' + t.dataset.target);
      t.scrollIntoView({ block: 'nearest', inline: 'center' });
    });
  });
  var hash = (location.hash || '').replace('#', '');
  var valid = Array.prototype.some.call(panels, function (p) { return p.id === hash; });
  activate(valid ? hash : 'terraform');
});
</script>

<section class="topic-section topic-panel active" id="terraform">
<h2>Terraform</h2>
<p>A complete Infrastructure as Code series: from the fundamentals of IaC to backends, CI/CD pipelines, blue/green and A/B testing deployments, multi-cloud, and securing state.</p>
{% assign posts = site.articles | where_exp: "post", "post.tags contains 'terraform'" | sort: "date" | reverse %}
{% if posts.size > 0 %}<div class="topic-cards">{% for post in posts %}<a class="topic-card" href="{{ post.url | relative_url }}">{% if post.image %}<div class="topic-card-image"><img src="{{ post.image | relative_url }}" alt="{{ post.title }}" loading="lazy"></div>{% else %}<div class="topic-card-image topic-card-placeholder"></div>{% endif %}<div class="topic-card-body"><time class="topic-card-date">{{ post.date | date: "%b %d, %Y" }}</time><h3 class="topic-card-title">{{ post.title }}</h3></div></a>{% endfor %}</div>{% else %}<p class="topic-empty">Articles coming soon.</p>{% endif %}
</section>

<section class="topic-section topic-panel" id="kubernetes">
<h2>Kubernetes</h2>
<p>Core concepts and hands-on practice for running workloads on Kubernetes, GitOps with ArgoCD, and day-to-day operational tips.</p>
{% assign posts = site.articles | where_exp: "post", "post.tags contains 'kubernetes'" | sort: "date" | reverse %}
{% if posts.size > 0 %}<div class="topic-cards">{% for post in posts %}<a class="topic-card" href="{{ post.url | relative_url }}">{% if post.image %}<div class="topic-card-image"><img src="{{ post.image | relative_url }}" alt="{{ post.title }}" loading="lazy"></div>{% else %}<div class="topic-card-image topic-card-placeholder"></div>{% endif %}<div class="topic-card-body"><time class="topic-card-date">{{ post.date | date: "%b %d, %Y" }}</time><h3 class="topic-card-title">{{ post.title }}</h3></div></a>{% endfor %}</div>{% else %}<p class="topic-empty">Articles coming soon.</p>{% endif %}
</section>

<section class="topic-section topic-panel" id="aws">
<h2>AWS</h2>
<p>Building and operating infrastructure on AWS, including the AWS CDK, cloud computing fundamentals, and real-world architecture practice.</p>
{% assign posts = site.articles | where_exp: "post", "post.tags contains 'aws'" | sort: "date" | reverse %}
{% if posts.size > 0 %}<div class="topic-cards">{% for post in posts %}<a class="topic-card" href="{{ post.url | relative_url }}">{% if post.image %}<div class="topic-card-image"><img src="{{ post.image | relative_url }}" alt="{{ post.title }}" loading="lazy"></div>{% else %}<div class="topic-card-image topic-card-placeholder"></div>{% endif %}<div class="topic-card-body"><time class="topic-card-date">{{ post.date | date: "%b %d, %Y" }}</time><h3 class="topic-card-title">{{ post.title }}</h3></div></a>{% endfor %}</div>{% else %}<p class="topic-empty">Articles coming soon.</p>{% endif %}
</section>

<section class="topic-section topic-panel" id="azure">
<h2>Azure</h2>
<p>Getting started with Microsoft Azure for cloud infrastructure.</p>
{% assign posts = site.articles | where_exp: "post", "post.tags contains 'azure'" | sort: "date" | reverse %}
{% if posts.size > 0 %}<div class="topic-cards">{% for post in posts %}<a class="topic-card" href="{{ post.url | relative_url }}">{% if post.image %}<div class="topic-card-image"><img src="{{ post.image | relative_url }}" alt="{{ post.title }}" loading="lazy"></div>{% else %}<div class="topic-card-image topic-card-placeholder"></div>{% endif %}<div class="topic-card-body"><time class="topic-card-date">{{ post.date | date: "%b %d, %Y" }}</time><h3 class="topic-card-title">{{ post.title }}</h3></div></a>{% endfor %}</div>{% else %}<p class="topic-empty">Articles coming soon.</p>{% endif %}
</section>

<section class="topic-section topic-panel" id="prometheus">
<h2>Prometheus</h2>
<p>Monitoring from the ground up: installing Prometheus, the Node Exporter, and the formulas behind CPU, memory, and disk-usage prediction.</p>
{% assign posts = site.articles | where_exp: "post", "post.tags contains 'prometheus'" | sort: "date" | reverse %}
{% if posts.size > 0 %}<div class="topic-cards">{% for post in posts %}<a class="topic-card" href="{{ post.url | relative_url }}">{% if post.image %}<div class="topic-card-image"><img src="{{ post.image | relative_url }}" alt="{{ post.title }}" loading="lazy"></div>{% else %}<div class="topic-card-image topic-card-placeholder"></div>{% endif %}<div class="topic-card-body"><time class="topic-card-date">{{ post.date | date: "%b %d, %Y" }}</time><h3 class="topic-card-title">{{ post.title }}</h3></div></a>{% endfor %}</div>{% else %}<p class="topic-empty">Articles coming soon.</p>{% endif %}
</section>

<section class="topic-section topic-panel" id="service-mesh">
<h2>Service Mesh</h2>
<p>Running a service mesh on Kubernetes with Istio.</p>
{% assign posts = site.articles | where_exp: "post", "post.tags contains 'service-mesh'" | sort: "date" | reverse %}
{% if posts.size > 0 %}<div class="topic-cards">{% for post in posts %}<a class="topic-card" href="{{ post.url | relative_url }}">{% if post.image %}<div class="topic-card-image"><img src="{{ post.image | relative_url }}" alt="{{ post.title }}" loading="lazy"></div>{% else %}<div class="topic-card-image topic-card-placeholder"></div>{% endif %}<div class="topic-card-body"><time class="topic-card-date">{{ post.date | date: "%b %d, %Y" }}</time><h3 class="topic-card-title">{{ post.title }}</h3></div></a>{% endfor %}</div>{% else %}<p class="topic-empty">Articles coming soon.</p>{% endif %}
</section>

<section class="topic-section topic-panel" id="networking">
<h2>Networking</h2>
<p>Networking fundamentals every DevOps engineer should know.</p>
{% assign posts = site.articles | where_exp: "post", "post.tags contains 'networking'" | sort: "date" | reverse %}
{% if posts.size > 0 %}<div class="topic-cards">{% for post in posts %}<a class="topic-card" href="{{ post.url | relative_url }}">{% if post.image %}<div class="topic-card-image"><img src="{{ post.image | relative_url }}" alt="{{ post.title }}" loading="lazy"></div>{% else %}<div class="topic-card-image topic-card-placeholder"></div>{% endif %}<div class="topic-card-body"><time class="topic-card-date">{{ post.date | date: "%b %d, %Y" }}</time><h3 class="topic-card-title">{{ post.title }}</h3></div></a>{% endfor %}</div>{% else %}<p class="topic-empty">Articles coming soon.</p>{% endif %}
</section>

<section class="topic-section topic-panel" id="linux">
<h2>Linux Tips</h2>
<p>Short, practical Linux tips for everyday work.</p>
{% assign posts = site.articles | where_exp: "post", "post.tags contains 'linux'" | sort: "date" | reverse %}
{% if posts.size > 0 %}<div class="topic-cards">{% for post in posts %}<a class="topic-card" href="{{ post.url | relative_url }}">{% if post.image %}<div class="topic-card-image"><img src="{{ post.image | relative_url }}" alt="{{ post.title }}" loading="lazy"></div>{% else %}<div class="topic-card-image topic-card-placeholder"></div>{% endif %}<div class="topic-card-body"><time class="topic-card-date">{{ post.date | date: "%b %d, %Y" }}</time><h3 class="topic-card-title">{{ post.title }}</h3></div></a>{% endfor %}</div>{% else %}<p class="topic-empty">Articles coming soon.</p>{% endif %}
</section>

<section class="topic-section topic-panel" id="devops">
<h2>DevOps</h2>
<p>General DevOps practices, tooling, and workflows across containers, CI/CD, and cloud.</p>
{% assign posts = site.articles | where_exp: "post", "post.tags contains 'devops'" | sort: "date" | reverse %}
{% if posts.size > 0 %}<div class="topic-cards">{% for post in posts %}<a class="topic-card" href="{{ post.url | relative_url }}">{% if post.image %}<div class="topic-card-image"><img src="{{ post.image | relative_url }}" alt="{{ post.title }}" loading="lazy"></div>{% else %}<div class="topic-card-image topic-card-placeholder"></div>{% endif %}<div class="topic-card-body"><time class="topic-card-date">{{ post.date | date: "%b %d, %Y" }}</time><h3 class="topic-card-title">{{ post.title }}</h3></div></a>{% endfor %}</div>{% else %}<p class="topic-empty">Articles coming soon.</p>{% endif %}
</section>
