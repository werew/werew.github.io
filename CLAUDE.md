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

## Writing Posts

Posts live in `_posts/` with filenames following the pattern `YYYY-MM-DD-title.md`. Front matter fields:

```yaml
---
title: "Post Title"
date: YYYY-MM-DD
categories: [Category]
tags: ['tag1', 'tag2']
img_path: "YYYY-MM-DD-post-slug"   # folder under assets/img/ for post images
image:
    path: "/banner.webp"           # relative to img_path
---
```

The `img_cdn` in `_config.yml` is set to `/assets/img/`, so post image folders should be placed under `assets/img/`.

## Architecture Notes

- **Theme**: All layouts, includes, and Sass come from the `jekyll-theme-chirpy` gem. Run `bundle info --path jekyll-theme-chirpy` to inspect theme files.
- **`_plugins/posts-lastmod-hook.rb`**: A Jekyll hook that uses `git log` to automatically set `last_modified_at` for posts that have been committed more than once.
- **`_tabs/`**: Top-level navigation pages (About, Archives, Categories, Tags) rendered as the site's sidebar tabs.
- **`_data/`**: Contains `contact.yml` (sidebar contact links) and `share.yml` (post sharing options).
- **`_site/`**: Generated output — not committed, excluded from Git.
