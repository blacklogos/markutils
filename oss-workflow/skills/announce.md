# /announce

Generate release announcements for social media, GitHub Discussions, and newsletters from your CHANGELOG.

## Usage

```bash
/announce                   # Announce latest version from CHANGELOG
/announce 1.4.0             # Announce specific version
/announce --platform x      # Generate for specific platform only
```

## Process

### Step 1: Extract Release Content

Read CHANGELOG.md and find the section for the target version:

```bash
# Find latest version header
VERSION=$(grep -oP '(?<=## v)\d+\.\d+\.\d+' CHANGELOG.md | head -1)
```

Extract:
- **Version number** and date
- **Feature list** (### New features)
- **Bug fixes** (### Bug fixes)
- **Product name** from README.md title
- **Download URL**: `https://github.com/OWNER/REPO/releases/tag/vX.Y.Z`
- **Landing page URL**: from CLAUDE.md, index.html canonical, or ask

### Step 2: Generate Per Platform

#### Twitter/X (280 chars)

```
🚀 [Product] vX.Y.Z

[Top feature in one sentence]

• Feature 1 (short)
• Feature 2 (short)
• Feature 3 (short)

↓ [download URL]

#opensource #[language] #[category]
```

Rules:
- Under 280 characters including URL
- Max 3 bullet points
- URL at the end
- 2-3 relevant hashtags

#### LinkedIn (longer form)

```
🚀 [Product] vX.Y.Z is out!

[2-3 sentence expansion: what's new and why it matters]

What's new:
✅ Feature 1 — one-sentence description
✅ Feature 2 — one-sentence description
✅ Feature 3 — one-sentence description

[One sentence about the project: open source, MIT license, etc.]

Download: [URL]
Source: [repo URL]

#OpenSource #[Language] #[Category]
```

#### GitHub Discussion / Release Notes

```markdown
## What's New in vX.Y.Z

[Full feature descriptions from CHANGELOG, reformatted for readability]

### Highlights

- **Feature 1**: [2-3 sentences]
- **Feature 2**: [2-3 sentences]

### Getting Started

[Install instructions — copy from README or landing page]

### Full Changelog

[Link to CHANGELOG.md]

---

If you find Clip useful, consider starring the repo ⭐
```

#### Newsletter / Email

```
Subject: [Product] vX.Y.Z — [Top Feature]

Hi,

[Product] vX.Y.Z is now available. Here's what's new:

[Feature list with short descriptions]

Download: [URL]

—
[Author]
```

#### Hacker News

```
Show HN: [Product] vX.Y.Z — [tagline]

[2-3 paragraphs: what it does, what's new, why it exists]

[URL]
```

### Step 3: Present and Copy

Show all generated announcements. For each, offer:
- "Copy to clipboard" action
- Character count (important for Twitter)
- Preview of how it renders

### Step 4: Suggest Posting Schedule

```
Recommended posting order:
1. GitHub Release notes (already done via /release)
2. Twitter/X — immediate
3. LinkedIn — same day
4. Hacker News — next morning (weekday, 8-10am ET)
5. Reddit r/[relevant] — same day as HN
```

## Voice Guidelines

From our copy-patterns reference:
- **Terse** — fewer words, then cut more
- **Technical** — assume the reader writes code
- **Confident** — state what it does, not what it "helps you" do
- **Honest** — no superlatives unless earned
- Avoid: "powerful", "seamless", "leverage", "comprehensive", "cutting-edge"

## Success Output

```
✓ Announcements generated for v1.4.0

  Twitter/X:    243 chars ✓ (under 280)
  LinkedIn:     487 words
  GH Discussion: ready
  Newsletter:   ready

  [Copied Twitter version to clipboard]

  Post in order: GH Release → Twitter → LinkedIn → HN (tomorrow 9am ET)
```
