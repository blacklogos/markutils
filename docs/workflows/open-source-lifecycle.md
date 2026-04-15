# Open Source Software Lifecycle Workflow

A repeatable workflow for creating, updating, and contributing to open source projects on GitHub — derived from the Clip project lifecycle (v1.0 → v1.4).

Works for solo developers, small teams, and AI-assisted development. Each phase has concrete commands, not abstract advice.

---

## Overview

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  PLAN   │───▶│  BUILD  │───▶│  SHIP   │───▶│ MARKET  │
└────┬────┘    └────┬────┘    └────┬────┘    └────┬────┘
     │              │              │              │
     ▼              ▼              ▼              ▼
  Issues         Feature        Release        Landing
  Milestones     Branches       DMG/pkg        Page
  Plan doc       PRs            Signing        Changelog
                 Tests          GH Release     Social
                                Appcast        OG Image
     │              │              │              │
     └──────────────┴──────┬───────┴──────────────┘
                           ▼
                      COMPOUND
                   (Document learnings)
```

---

## Phase 1: Plan

**When**: Before starting a new version or feature batch.

### 1.1 Triage Issues

```bash
# List all open issues
gh issue list --state open

# Create issues for new features/bugs
gh issue create --title "feat: Description" --body "## Summary\n..."

# Label and prioritize
gh issue edit <number> --add-label "enhancement"
```

### 1.2 Create Milestones

Group related issues into milestones = point releases.

```bash
# Create milestone per release
gh api repos/OWNER/REPO/milestones --method POST \
  -f title="v1.5.0 — Feature Name" \
  -f description="Phase description" \
  -f due_on="2026-05-01T00:00:00Z"

# Link issues to milestones
gh issue edit <number> --milestone "v1.5.0 — Feature Name"
```

**Pattern from Clip**: Each phase got its own milestone (v1.3.1, v1.3.2, v1.3.3, v1.4.0) so phases could ship independently.

### 1.3 Write Plan Document

```bash
mkdir -p docs/plans/
# Filename: YYYY-MM-DD-NNN-type-descriptive-name-plan.md
```

**Structure:**
```markdown
---
title: "v1.5.0 — Feature Name"
type: feat
status: active
date: YYYY-MM-DD
issues: [#10, #11, #12]
---

# Overview
| Phase | Issues | Theme | Risk |
|-------|--------|-------|------|

# Per Phase
## Phase N — Name
- What changes
- Which files
- Key code patterns
- Acceptance criteria
```

**Key principle**: Phases are independent — each can ship as a point release without blocking the next.

---

## Phase 2: Build

**When**: Executing the plan, one phase at a time.

### 2.1 Branch Per Phase

```bash
git checkout main && git pull origin main
git checkout -b feat/descriptive-name
```

### 2.2 Implement

Follow existing patterns. Read the code you're changing before modifying it.

```bash
# Build continuously
swift build          # or: npm run build, cargo build, etc.

# Run tests after each change
swift test           # or: npm test, pytest, etc.

# Project-specific verification
./scripts/verify_release.sh
```

### 2.3 Commit Conventions

```
feat(scope): what and why          # New feature
fix(scope): what was broken        # Bug fix
docs: what was documented          # Documentation
chore: what was cleaned up         # Maintenance
release: vX.Y.Z — summary         # Version release
```

### 2.4 PR Per Phase

```bash
git push -u origin feat/descriptive-name

gh pr create \
  --title "feat: Descriptive title" \
  --body "## Summary\n- ...\n\nCloses #N" \
  --milestone "vX.Y.Z — Name"
```

**PR body template:**
```markdown
## Summary
- What was built and why

Closes #N

## Testing
- Tests added/modified
- verify_release.sh passes

## Post-Deploy
No additional monitoring required: [reason]
```

### 2.5 Merge and Repeat

```bash
gh pr merge <number> --squash --delete-branch
git checkout main && git pull origin main
git checkout -b feat/next-phase
```

---

## Phase 3: Ship

**When**: All phases for a version are merged to main.

### 3.1 Version Bump

Update version strings in all locations:
```bash
# Find all version references
grep -r "1\.4\.0" --include="*.swift" --include="*.sh" --include="*.md" --include="*.html" --include="*.xml"
```

Common locations:
- `scripts/build_dmg.sh` (VERSION, BUILD_NUMBER, Info.plist)
- `Sources/Services/UpdateChecker.swift` (if custom updater)
- `README.md`
- `CHANGELOG.md`
- `index.html` (landing page)
- `appcast.xml` (Sparkle)

### 3.2 Update Changelog

```markdown
## vX.Y.Z — YYYY-MM-DD

### New features
**Feature Name** (#issue)
- Bullet point description

### Bug fixes
- What was fixed

### Changes
- What changed but isn't a feature or fix
```

### 3.3 Build Release Artifact

```bash
./scripts/build_dmg.sh    # or: npm pack, cargo build --release, etc.
```

### 3.4 Sign (if applicable)

```bash
# Sparkle EdDSA signing
.build/artifacts/sparkle/Sparkle/bin/sign_update Product-X.Y.Z.dmg
# → sparkle:edSignature="..." length="..."

# Update appcast.xml with new <item> entry
```

### 3.5 Create GitHub Release

```bash
gh release create vX.Y.Z \
  ./Product-X.Y.Z.dmg \
  --title "Product vX.Y.Z — Summary" \
  --notes "## What's New\n..."
```

### 3.6 Verify

```bash
# Download the release artifact and test it
# On a second machine if possible
```

---

## Phase 4: Market

**When**: After shipping a release.

### 4.1 Update Landing Page

```bash
# Edit index.html — version badge, feature cards, getting started, FAQ

# Deploy to Cloudflare Pages (Direct Upload)
cp index.html /tmp/deploy/
npx wrangler pages deploy /tmp/deploy --project-name=PROJECT --branch=main

# Or GitHub Pages: just push — auto-deploys from docs/ or root
```

### 4.2 Update OG Image

```bash
# Edit og-image.html with new version
node render-og.cjs    # Renders HTML → PNG via WebKit
# Commit og-image.png
```

### 4.3 Social / Announcement

Reusable announcement template:
```
🚀 [Product] vX.Y.Z

[One sentence: what's new]

• Feature 1
• Feature 2  
• Feature 3

Download: [release URL]
Docs: [landing page URL]

#opensource #macos #devtools
```

### 4.4 Landing Page Anatomy

```
Hero          → Icon + name + tagline + CTA buttons
Demo          → Terminal window with real commands
Features      → 3 cards (most differentiating)
Detail        → Alternating sections with code examples
Get Started   → Numbered steps with terminal snippets
FAQ           → Accordion (6 common questions)
Footer        → Author + license + source link
```

---

## Phase 5: Compound (Document Learnings)

**When**: After solving any non-obvious problem.

### 5.1 Write Solution Doc

```bash
mkdir -p docs/solutions/[category]/
# Categories: build-errors/, runtime-errors/, best-practice/, ui-bugs/, etc.
```

**Structure:**
```markdown
---
title: "Problem title"
category: build-errors
date: YYYY-MM-DD
tags: [relevant, tags]
component: path/to/affected/file.swift
related:
  - docs/solutions/other-doc.md
---

## Problem
[Exact error message or symptom]

## Root Cause
[Why it happened — 2-3 sentences]

## Solution
[Code snippets showing the fix]

## Prevention
[How to avoid this in the future]
```

### 5.2 When to Compound

- Build error that took >5 minutes to diagnose
- Runtime crash with a non-obvious root cause
- Architecture decision that has trade-offs
- Deployment issue (signing, packaging, CDN)
- Pattern that will recur across projects

---

## Contributing Workflow (for external contributors)

### For Contributors

```bash
# 1. Fork and clone
gh repo fork OWNER/REPO --clone

# 2. Create feature branch
git checkout -b feat/my-feature

# 3. Make changes, following existing patterns
# 4. Run tests
swift test && ./scripts/verify_release.sh

# 5. Commit with conventional messages
git commit -m "feat(scope): description"

# 6. Push and create PR
git push origin feat/my-feature
gh pr create --title "feat: Description" --body "Closes #N"
```

### For Maintainers

```bash
# Review PR
gh pr view <number>
gh pr diff <number>

# Merge
gh pr merge <number> --squash --delete-branch

# If the PR closes a milestone, proceed to Ship phase
```

### CONTRIBUTING.md Template

```markdown
# Contributing to [Product]

## Quick Start
1. Fork and clone
2. `swift build` to verify setup
3. Create a branch: `git checkout -b feat/my-feature`
4. Make changes following existing code patterns
5. Run `./scripts/verify_release.sh` before pushing
6. Open a PR with a clear description

## Conventions
- Commit messages: `feat:`, `fix:`, `docs:`, `chore:`
- One PR per feature/fix
- All tests must pass
- No new dependencies without discussion

## Architecture
See README.md § Architecture for the source tree and target graph.

## Need Help?
Open an issue or start a discussion.
```

---

## Quick Reference Card

| Task | Command |
|------|---------|
| New issue | `gh issue create --title "feat: ..."` |
| New milestone | `gh api repos/O/R/milestones --method POST -f title="v1.5.0"` |
| Feature branch | `git checkout -b feat/name` |
| Build | `swift build` |
| Test | `swift test && ./scripts/verify_release.sh` |
| PR | `gh pr create --title "feat: ..." --milestone "v1.5.0"` |
| Merge | `gh pr merge N --squash --delete-branch` |
| Tag release | `gh release create vX.Y.Z ./artifact.dmg --title "..."` |
| Sign (Sparkle) | `.build/.../sign_update Product.dmg` |
| Deploy site | `npx wrangler pages deploy /tmp/deploy --project-name=X --branch=main` |
| Document fix | Write `docs/solutions/category/slug-YYYYMMDD.md` |

---

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Commit directly to main for features | Feature branch → PR → squash merge |
| Ship without testing | `verify_release.sh` before every release |
| Hand-edit appcast.xml signatures | Use `sign_update` / `generate_appcast` |
| Skip changelog | Update CHANGELOG.md before tagging |
| Forget to update landing page | Deploy after every release |
| Solve a hard problem and move on | `/compound` — document it in `docs/solutions/` |
| One giant PR for a multi-feature release | One PR per phase, merge sequentially |
| Version string in one place | `grep -r` to find all version references |

---

## Reuse This Workflow

This workflow is project-agnostic. To adapt for a different project:

1. Replace `swift build/test` with your language's build/test commands
2. Replace `build_dmg.sh` with your packaging script
3. Replace Sparkle/appcast with your update mechanism (or remove)
4. Replace Cloudflare Pages with your hosting (Vercel, Netlify, GH Pages)
5. Keep the phases: **Plan → Build → Ship → Market → Compound**
