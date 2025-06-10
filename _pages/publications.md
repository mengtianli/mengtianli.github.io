---
layout: page
permalink: /publications/
title: publications
description:
nav: true
nav_order: 2
---

<style>
.bibliography .type {
  display: none !important;
}
</style>

<!-- Group by venue type -->
<h2>Conference Proceedings</h2>
{% bibliography -q @inproceedings %}

<h2>Journal Articles</h2>
{% bibliography -q @article %}

<h2>Preprints & Others</h2>
{% bibliography -q @misc %}

</div>
