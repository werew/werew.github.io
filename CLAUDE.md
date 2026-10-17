# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal blog ([ret2libc.com](https://www.ret2libc.com)) built with Jekyll using the [Chirpy theme](https://github.com/cotes2020/jekyll-theme-chirpy). Content focuses on security research, CTF writeups, and computer science topics. Ruby version: 3.3.5.

## Commands

```bash
# Install dependencies
bundle install

# Serve locally with live reload
bundle exec jekyll serve

# Build for production
bundle exec jekyll build

# Build and test (mirrors CI pipeline)
bundle exec jekyll b -d "_site"
bundle exec htmlproofer _site --disable-external=true \
  --ignore-urls "/^http:\/\/127.0.0.1/,/^http:\/\/0.0.0.0/,/^http:\/\/localhost/"
```

## Deployment

Pushing to `main` triggers the GitHub Actions workflow (`.github/workflows/pages-deploy.yml`), which builds and deploys to GitHub Pages automatically. No manual deployment needed.

The workflow runs `jekyll build` itself rather than relying on GitHub's native
Pages builder, which is what allows the custom hooks in `_plugins/` to run.
Anything that depends on a plugin will silently stop working if the site is ever
switched to the native builder.

`_config.yml` excludes `CLAUDE.md` from the build, so this file is not published
at `/CLAUDE.md`.

## Writing Posts

Posts live in `_posts/` with filenames following the pattern `YYYY-MM-DD-title.md`. Front matter fields:

```yaml
---
title: "Post Title"
description: "One or two sentences. Aim <=160 chars, hard cap ~190."
date: YYYY-MM-DD
categories: [Category]
tags: ['tag1', 'tag2']
img_path: "YYYY-MM-DD-post-slug"   # folder under assets/img/ for post images
image:
    path: "/banner.webp"           # relative to img_path
---
```

`description` is not optional in practice. It feeds four things at once: the
meta description, the Open Graph tags, the schema.org `BlogPosting`, and the
post's entry in `/llms.txt` and `/llms-full.txt`. Without it, all of them fall
back to the post's opening paragraph, which rarely states what the post is
about.

Length matters because of those consumers:

- **Aim for <=160 characters.** Google truncates meta descriptions at roughly
  that point.
- **Treat ~190 as a hard cap.** The landing-page cards render the description in
  full with no line clamp, so a long one makes its card noticeably taller than
  its neighbours. Existing descriptions run 129-188 characters.
- Front-load the subject. The description is the only summary a reader, a search
  result, or an LLM sees before the post itself.

The `img_cdn` in `_config.yml` is set to `/assets/img/`, so post image folders should be placed under `assets/img/`.

## Architecture Notes

- **Theme**: Layouts, includes, and Sass come from the `jekyll-theme-chirpy` gem
  (pinned `~> 6.2, <= 7.1.1`; currently 6.5.5). Run
  `bundle info --path jekyll-theme-chirpy` to inspect theme files.
- **Theme overrides**: a local file at the same path shadows the gem's copy.
  Three files do this and **must be re-checked when upgrading the theme**, since
  an upgrade will not merge changes into them: `_layouts/home.html`,
  `assets/css/jekyll-theme-chirpy.scss` and `assets/robots.txt`. A fourth file,
  `_includes/metadata-hook.html`, is an intentional extension point provided by
  the theme and is safe across upgrades. Never place a shadowing file at a
  *different* path than the original (see the `robots.txt` note below).
- **`_plugins/posts-lastmod-hook.rb`**: A Jekyll hook that uses `git log` to automatically set `last_modified_at` for posts that have been committed more than once.
- **`_layouts/home.html`**: A copy of the theme's layout, overridden so the post
  cards on the landing page show the post's `description` (falling back to the
  body excerpt) instead of the first 200 characters of the body. It is rendered
  in full, with `truncate: 300` only as a backstop against a runaway
  description, so the practical limit is the ~190 characters noted above.
- **`assets/css/jekyll-theme-chirpy.scss`**: Shadows the theme's stylesheet
  entry point (`@import 'main'` plus custom rules). Currently removes the
  theme's two-line clamp on the landing-page card text so descriptions show in
  full; card heights therefore vary between rows. Note that `pwa.enabled` is on,
  so the service worker caches CSS — **a hard reload (or clearing site data) is
  required to see any stylesheet change locally**, otherwise the old CSS is
  served from the cache and the change looks like it did not apply.
- **`_tabs/`**: Top-level navigation pages (About, Archives, Categories, Tags) rendered as the site's sidebar tabs.
- **`_data/`**: Contains `contact.yml` (sidebar contact links) and `share.yml` (post sharing options).
- **`_site/`**: Generated output — not committed, excluded from Git.

## SEO and AI discoverability

Four endpoints exist to make the blog legible to search engines, AI search and
LLM crawlers. They are generated at build time, so new posts are picked up
automatically — none of them need to be edited when publishing a post.

- **`llms.txt`** → `/llms.txt`: curated index in the [llms.txt](https://llmstxt.org/)
  format. A Liquid template that lists the latest posts, every post grouped by
  its first category (title, date, tags, `description`), the standalone
  projects, and the machine-readable endpoints. Edit it when adding a project
  under a `static_asset_dirs` directory, since those are listed by hand.
- **`_plugins/llms-full-txt.rb`** → `/llms-full.txt`: a `:post_write` hook that
  concatenates the raw Markdown source of every post into one file. It reads the
  files from disk rather than using `post.content`, so bodies are never
  re-rendered into HTML.
- **`assets/robots.txt`** → `/robots.txt`: overrides the theme's
  `assets/robots.txt` by shadowing its path (do not add a second `robots.txt` at
  the repo root — Jekyll reports a destination conflict and the winner is
  undefined). Explicitly allows the AI search and assistant crawlers.
- **`ai.txt`** → `/ai.txt`: AI/ML usage policy in the Spawning `ai.txt` format,
  stating that the content may be crawled, embedded and quoted with attribution.

Additionally, **`_includes/metadata-hook.html`** (a Chirpy extension point
included from `head.html`) emits a schema.org `@graph` with the author `Person`
(with `sameAs` and `knowsAbout`) and the `Blog` entity, which `jekyll-seo-tag`
does not cover, plus `<link rel="alternate">` pointing at `/llms.txt`. The
per-page `BlogPosting`/`WebSite` JSON-LD still comes from `jekyll-seo-tag`;
keep the two from overlapping. The top-level `author` key in `_config.yml`
exists so `jekyll-seo-tag` includes author metadata — Chirpy's visible byline
uses `site.social.name` and `page.author` is a key into `_data/authors.yml`, so
it does not affect the layout.
