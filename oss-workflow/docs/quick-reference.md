# Quick Reference — OSS Workflow

One-page cheat sheet. Print it, pin it, refer to it.

---

## The Loop

```
/brainstorming → /ce:plan → /ce:work → /ce:review → /release → /announce → /ce:compound
```

---

## Phase 1: Plan

```bash
/brainstorming                       # Explore what to build
/ce:plan                             # Write implementation plan
/deepen-plan                         # Add research depth to plan
gh issue create --title "feat: ..."  # Create issue
gh issue edit N --milestone "v1.5"   # Link to milestone
```

## Phase 2: Build

```bash
git checkout -b feat/name            # Feature branch
/ce:work @docs/plans/plan.md        # Execute plan
swift test                           # Test continuously
./scripts/verify_release.sh          # Pre-ship check
gh pr create --milestone "v1.5"      # Open PR
/ce:review                           # Code review
gh pr merge N --squash               # Merge
```

## Phase 3: Ship

```bash
/release 1.5.0                       # Full pipeline:
                                     #   bump → build → sign → tag
                                     #   → gh release → deploy site
                                     #   → close milestone
```

## Phase 4: Market

```bash
/announce                            # Twitter + LinkedIn + HN posts
# Edit index.html                    # Update landing page
npx wrangler pages deploy ...        # Deploy to Cloudflare
```

## Phase 5: Compound

```bash
/ce:compound                         # Document a solved problem
/contribute                          # Generate CONTRIBUTING.md
```

---

## Common Combos

| Situation | Commands |
|-----------|----------|
| **New feature, start to finish** | `/brainstorming` → `/ce:plan` → `/ce:work` → `/release` → `/announce` |
| **Quick bug fix** | branch → fix → `verify_release.sh` → PR → `/release patch` |
| **Multi-feature release** | `/ce:plan` (phased) → `/ce:work` per phase → `/release minor` → `/announce` |
| **First open source release** | `/contribute` → `/release 1.0.0` → landing page → `/announce` |
| **Hard bug, now fixed** | `/ce:compound` (document it before you forget) |

---

## Commit Conventions

```
feat(scope): new feature             fix(scope): bug fix
docs: documentation                  chore: maintenance
release: vX.Y.Z — summary           refactor(scope): restructure
```

---

## GitHub CLI Essentials

```bash
gh issue list                        # Open issues
gh issue create --title "..."        # New issue
gh pr create --title "..." --milestone "v1.5"  # New PR
gh pr merge N --squash               # Merge PR
gh release create vX.Y.Z ./file.dmg  # Create release
gh release upload vX.Y.Z ./file.dmg --clobber  # Update artifact
```
