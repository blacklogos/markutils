---
title: "Cloudflare Pages Direct Upload via Wrangler CLI"
category: best-practice
date: 2026-04-08
tags: [cloudflare, wrangler, deployment, static-site, landing-page]
component: docs/index.html, index.html
related:
  - docs/solutions/best-practice/swift-cli-clipboard-dmg-bundling-20260406.md
---

## Problem

Landing page at `clip.cc4.marketing` was not updating after git pushes to `origin/main`. Changes to `index.html` were committed and pushed but the live site showed stale content from April 6.

## Root Cause

The Cloudflare Pages project (`clip-app`) was configured as **Direct Upload** — not git-connected. Direct Upload projects do not watch a GitHub repository for changes. Deployments only happen when files are explicitly uploaded via the Cloudflare dashboard or the Wrangler CLI.

The Cloudflare Pages dashboard showed: "Assets uploaded: 1 Files uploaded — index.html" with a deployment timestamp of April 6, confirming no automatic deployments had occurred since the initial manual upload.

## Solution

Use the Wrangler CLI to deploy directly:

```bash
# Stage files for deployment
mkdir -p /tmp/clip-deploy
cp index.html /tmp/clip-deploy/
cp og-image.png /tmp/clip-deploy/

# Deploy to production (--branch=main targets the production environment)
npx wrangler pages deploy /tmp/clip-deploy --project-name=clip-app --branch=main
```

Key flags:
- `--project-name=clip-app` — matches the Cloudflare Pages project name
- `--branch=main` — deploys to the production environment (without this, it creates a preview deployment)
- `--commit-dirty=true` — suppresses warning when working directory has uncommitted changes

## How It Works

Cloudflare Pages supports two deployment workflows:

| Workflow | Trigger | Use Case |
|----------|---------|----------|
| **Git-Connected** | Auto-deploy on push | Public repos, CI/CD pipelines |
| **Direct Upload** | `wrangler pages deploy` | Private repos, manual control, no CI needed |

Direct Upload is ideal when:
- The repo is not public (or you don't want Cloudflare to have repo access)
- You want to decouple site deployment from code pushes
- The landing page is a single HTML file with no build step

## Prevention

1. **Document the deployment method** — note in README or CLAUDE.md that this project uses Direct Upload
2. **Add a deploy script** — `scripts/deploy-site.sh`:
   ```bash
   #!/bin/bash
   cp index.html /tmp/clip-deploy/
   cp og-image.png /tmp/clip-deploy/
   npx wrangler pages deploy /tmp/clip-deploy --project-name=clip-app --branch=main --commit-dirty=true
   ```
3. **Check after release** — after tagging a new version, verify the landing page version badge matches
