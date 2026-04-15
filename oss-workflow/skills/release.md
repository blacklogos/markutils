# /release

Automate the full release pipeline: version bump, build, sign, tag, publish, deploy.

## Usage

```bash
/release                    # Interactive — prompts for version
/release 1.5.0              # Release specific version
/release patch              # Auto-bump patch (1.4.0 → 1.4.1)
/release minor              # Auto-bump minor (1.4.0 → 1.5.0)
/release major              # Auto-bump major (1.4.0 → 2.0.0)
```

## Process

### Step 1: Determine Version

If no version argument provided, read current version and ask:

```bash
# Auto-detect current version from CHANGELOG.md, Package.swift, or build script
CURRENT=$(grep -oP '(?<=Version )\d+\.\d+\.\d+' README.md | head -1)
```

**Ask:** "Current version is `{CURRENT}`. Release as: (a) patch `X.Y.Z+1`, (b) minor `X.Y+1.0`, (c) major `X+1.0.0`, or (d) custom?"

### Step 2: Pre-flight Checks

Run before anything else — abort if any fail:

```bash
# 1. Clean working tree
git diff --exit-code || { echo "Uncommitted changes"; exit 1; }

# 2. On main branch
[[ $(git branch --show-current) == "main" ]] || { echo "Not on main"; exit 1; }

# 3. Tests pass
./scripts/verify_release.sh || { echo "Tests failing"; exit 1; }

# 4. No open PRs for this milestone
gh pr list --state open --json number | jq length  # Should be 0
```

### Step 3: Version Bump

Find and replace ALL version references:

```bash
# Find all files containing the old version string
grep -rl "$OLD_VERSION" --include="*.swift" --include="*.sh" --include="*.md" \
    --include="*.html" --include="*.xml" --include="*.json" .
```

Common locations to update:
- `scripts/build_dmg.sh` — VERSION, BUILD_NUMBER, Info.plist
- `README.md` — version badge
- `CHANGELOG.md` — new version section (must be added, not just bumped)
- `index.html` — landing page version badge, DMG filename
- `appcast.xml` — new `<item>` entry (after signing)
- `Sources/**/UpdateChecker.swift` — currentVersion (if custom updater)
- `Package.swift` — only if version is declared there

**Increment BUILD_NUMBER** (integer) alongside the semver string.

### Step 4: Update Changelog

If CHANGELOG.md doesn't already have a section for the new version, create one:

```markdown
## vX.Y.Z — YYYY-MM-DD

### New features
[Extract from merged PRs since last tag]

### Bug fixes
[Extract from merged PRs with "fix:" prefix]

### Changes
[Everything else]
```

**Auto-extract from git log:**
```bash
LAST_TAG=$(git describe --tags --abbrev=0)
git log ${LAST_TAG}..HEAD --oneline --no-merges
```

### Step 5: Commit Version Bump

```bash
git add -A
git commit -m "release: vX.Y.Z — summary of what shipped"
```

### Step 6: Build Release Artifact

```bash
./scripts/build_dmg.sh    # or: npm pack, cargo build --release, etc.
```

### Step 7: Sign (if Sparkle/code signing configured)

```bash
# Sparkle EdDSA signing
SIGN_TOOL=$(find .build -name "sign_update" -type f | head -1)
if [ -n "$SIGN_TOOL" ]; then
    SIG=$("$SIGN_TOOL" Product-X.Y.Z.dmg)
    # Parse: sparkle:edSignature="..." length="..."
    # Update appcast.xml with new <item>
    git add appcast.xml
    git commit --amend --no-edit
fi
```

### Step 8: Tag and Push

```bash
git tag vX.Y.Z
git push origin main --tags
```

### Step 9: Create GitHub Release

```bash
gh release create vX.Y.Z \
    ./Product-X.Y.Z.dmg \
    --title "Product vX.Y.Z — Summary" \
    --notes-file /tmp/release-notes.md
```

Release notes extracted from the CHANGELOG section for this version.

### Step 10: Deploy Landing Page

```bash
# Cloudflare Pages (Direct Upload)
cp index.html /tmp/deploy/
npx wrangler pages deploy /tmp/deploy --project-name=PROJECT --branch=main --commit-dirty=true

# Or GitHub Pages — already deployed via push

# Or Vercel/Netlify — auto-deploys on push
```

### Step 11: Close Milestone

```bash
MILESTONE_NUMBER=$(gh api repos/OWNER/REPO/milestones \
    --jq ".[] | select(.title | contains(\"vX.Y.Z\")) | .number")
gh api repos/OWNER/REPO/milestones/$MILESTONE_NUMBER \
    --method PATCH -f state="closed"
```

### Step 12: Announce

Suggest running `/announce` to generate social posts.

## Success Output

```
✓ Release vX.Y.Z complete

  Version bump:  8 files updated
  Build:         Product-X.Y.Z.dmg (5.9 MB)
  Signed:        EdDSA ✓
  Tag:           vX.Y.Z pushed
  Release:       https://github.com/OWNER/REPO/releases/tag/vX.Y.Z
  Landing page:  https://product.example.com (deployed)
  Milestone:     closed

  Next: /announce to generate social posts
```
