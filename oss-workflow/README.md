# OSS Workflow

A complete workflow system for creating, shipping, and marketing open source software — powered by Claude Code slash commands.

**5 phases. 20+ skills. One repeatable loop.**

```
Plan → Build → Ship → Market → Compound
  ↑                                  ↓
  └──────────────────────────────────┘
```

---

## Quick Start

```bash
# 1. Plan a feature
/brainstorming              # Explore what to build
/ce:plan                    # Write implementation plan

# 2. Build it
/ce:work @plan.md           # Execute the plan
/ce:review                  # Code review before merge

# 3. Ship it
/release 1.5.0              # Version bump → build → sign → tag → publish

# 4. Market it
/announce                   # Generate social posts from changelog
/create-landing-page        # Build product landing page

# 5. Compound knowledge
/ce:compound                # Document what you learned
```

---

## Installation

Copy the `skills/` folder into your Claude Code skills directory:

```bash
# Option A: Global skills (available in all projects)
cp -R skills/* ~/.claude/skills/

# Option B: Project-local skills
mkdir -p .claude/skills/
cp -R skills/* .claude/skills/
```

Or reference from a Dropbox/cloud folder in your Claude Code settings.

---

## Workflow Phases

### Phase 1: Plan

Clarify WHAT to build before diving into HOW.

| Task | Command | Output |
|------|---------|--------|
| Explore ideas | `/brainstorming` | Structured design decisions |
| Refine requirements | `/ce:brainstorm` | Collaborative dialogue |
| Write plan | `/ce:plan` | `docs/plans/YYYY-MM-DD-plan.md` |
| Add depth | `/deepen-plan` | Enhanced plan with research |
| Review plan | `/document-review` | Refined plan document |
| Triage bugs | `/triage` | Prioritized issue list |

**GitHub integration:**
```bash
gh issue create --title "feat: ..."       # Create issues
gh api repos/O/R/milestones --method POST # Create milestones
gh issue edit N --milestone "v1.5.0"      # Link to milestone
```

### Phase 2: Build

Execute the plan with quality gates.

| Task | Command | Output |
|------|---------|--------|
| Execute plan | `/ce:work @plan.md` | Working code + tests |
| Fast mode | `/lfg` or `/slfg` | Quick implementation |
| Parallel work | `/git-worktree` | Isolated worktrees |
| Code review | `/ce:review` | Multi-agent review |
| Fix PR comments | `/resolve-pr-parallel` | Resolved review feedback |
| Clean up TODOs | `/resolve_todo_parallel` | Resolved TODOs |
| Frontend design | `/frontend-design` | Polished UI code |
| Bug reproduction | `/reproduce-bug` | Verified bug report |
| Run tests | `/test-xcode` or `/test-browser` | Test results |

**Branch workflow:**
```bash
git checkout -b feat/name      # Branch per feature
# ... implement ...
gh pr create --milestone "v1.5.0"
gh pr merge N --squash --delete-branch
```

### Phase 3: Ship

Release with everything signed, tagged, and deployed.

| Task | Command | Output |
|------|---------|--------|
| Full release | `/release 1.5.0` | Tag + artifact + GH release |
| Changelog only | `/changelog` | Updated CHANGELOG.md |
| Deploy docs | `/deploy-docs` | Published documentation |

**The `/release` pipeline:**
```
Pre-flight checks → Version bump → Changelog → Build → Sign →
Tag → Push → GH Release → Deploy landing page → Close milestone
```

### Phase 4: Market

Make people aware of what you shipped.

| Task | Command | Output |
|------|---------|--------|
| Announcements | `/announce` | Twitter, LinkedIn, HN posts |
| Landing page | `/create-landing-page`* | Product landing page HTML |
| OG image | `/gemini-imagegen` | Social share image |
| Feature video | `/feature-video` | Video walkthrough for PR/docs |
| Brand copy | `/write` or `/rewrite` | Marketing copy |
| Upload assets | `/rclone` | Files on S3/R2/Dropbox |
| Screenshots | `/agent-browser` | UI screenshots |

*Uses the landing page workflow from `workflows/create-landing-page.md`

### Phase 5: Compound

Document what you learned so it compounds over time.

| Task | Command | Output |
|------|---------|--------|
| Document fix | `/ce:compound` | `docs/solutions/category/slug.md` |
| Contributing guide | `/contribute` | `CONTRIBUTING.md` |

---

## Skill Map

### Which skill for which situation?

```
"I have a vague idea"                → /brainstorming
"I know what to build, need a plan"  → /ce:plan
"I have a plan, let's execute"       → /ce:work @plan.md
"Just build it fast"                 → /lfg
"Review this code"                   → /ce:review
"Ship this version"                  → /release
"Tell people about it"               → /announce
"Need a landing page"                → /create-landing-page
"I fixed a hard bug"                 → /ce:compound
"Need contributor docs"              → /contribute
"PR has review comments"             → /resolve-pr-parallel
"Multiple features in parallel"      → /git-worktree
```

### Skill Dependencies

```
/brainstorming ──→ /ce:plan ──→ /ce:work ──→ /ce:review
                       │                         │
                       └── /deepen-plan          │
                                                  ▼
                                    /release ──→ /announce
                                       │
                                       └──→ /deploy-docs
                                       
Independent (use anytime):
  /ce:compound   /contribute   /git-worktree   /frontend-design
  /triage        /reproduce-bug   /test-xcode   /agent-browser
```

---

## Templates

### Issue Template
```markdown
## Summary
[What needs to happen]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Context
[Any relevant background]
```

### PR Template
```markdown
## Summary
- What was built and why

Closes #N

## Testing
- Tests added/modified
- verify_release.sh passes
```

### Announcement Template (Twitter)
```
🚀 [Product] vX.Y.Z

[One sentence: what's new]

• Feature 1
• Feature 2
• Feature 3

↓ [URL]

#opensource #[lang] #[category]
```

---

## File Structure

```
oss-workflow/
├── README.md                  # This file
├── skills/
│   ├── release.md             # /release — full release pipeline
│   ├── announce.md            # /announce — social media announcements
│   └── contribute.md          # /contribute — generate CONTRIBUTING.md
├── docs/
│   ├── workflow.md            # Complete lifecycle reference
│   └── quick-reference.md     # One-page cheat sheet
└── templates/
    ├── CONTRIBUTING.md         # Ready-to-use contributing guide
    ├── ISSUE_TEMPLATE.md       # Issue template
    ├── PULL_REQUEST_TEMPLATE.md # PR template
    └── CHANGELOG-ENTRY.md      # Changelog entry template
```

---

## Works With

This workflow integrates with the [Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin) skill set. The three new skills (`/release`, `/announce`, `/contribute`) fill gaps in the existing pipeline:

| Phase | Compound Engineering Skills | New Skills (this repo) |
|-------|---------------------------|----------------------|
| Plan | `/brainstorming`, `/ce:plan`, `/deepen-plan` | — |
| Build | `/ce:work`, `/lfg`, `/ce:review` | — |
| Ship | `/changelog`, `/deploy-docs` | **`/release`** |
| Market | `/frontend-design`, `/feature-video` | **`/announce`** |
| Compound | `/ce:compound` | **`/contribute`** |

---

## License

MIT
