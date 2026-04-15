# /contribute

Generate or update CONTRIBUTING.md by analyzing your codebase's conventions, build system, test patterns, and commit style.

## Usage

```bash
/contribute                 # Generate CONTRIBUTING.md from codebase analysis
/contribute update          # Update existing CONTRIBUTING.md with current state
```

## Process

### Step 1: Analyze Codebase

Read these sources **in parallel** to extract project conventions:

| Source | What to Extract |
|--------|----------------|
| `CLAUDE.md` / `AGENT_RULES.md` | Coding standards, test requirements, mandatory checks |
| `Package.swift` / `package.json` / `Cargo.toml` | Language, dependencies, targets, build commands |
| `scripts/` directory | Build scripts, test scripts, release scripts |
| `.gitignore` | What's excluded (reveals tooling and artifacts) |
| `git log --oneline -20` | Commit message conventions (feat:, fix:, docs:) |
| `Tests/` directory | Test framework, test patterns, what's covered |
| `README.md` | Architecture section, install instructions |
| `.github/workflows/` | CI configuration (if exists) |

### Step 2: Detect Conventions

From the analysis, determine:

```yaml
language: Swift          # From Package.swift / package.json / etc.
build_command: "swift build"
test_command: "swift test"
verify_command: "./scripts/verify_release.sh"    # If exists
commit_style: "conventional"    # feat:, fix:, docs:, chore:
branch_strategy: "feature-branch"    # Feature branches → PR → squash merge
pr_style: "squash"
code_review: "required"    # or: optional
linter: "none"    # or: swiftlint, eslint, rubocop, etc.
ci: "none"    # or: github-actions, etc.
```

### Step 3: Generate CONTRIBUTING.md

Write the file using the detected conventions:

```markdown
# Contributing to [Product]

Thanks for your interest in contributing! This guide will help you get started.

## Development Setup

### Prerequisites
- [Language] [version]+ ([detected from project config])
- [Any other tools: Xcode, Node, etc.]

### Clone and Build
\`\`\`bash
git clone https://github.com/OWNER/REPO.git
cd REPO
[build_command]
\`\`\`

### Run Tests
\`\`\`bash
[test_command]
[verify_command if exists]
\`\`\`

## Making Changes

### 1. Create a Branch
\`\`\`bash
git checkout main && git pull
git checkout -b feat/your-feature    # or: fix/bug-description
\`\`\`

### 2. Follow Existing Patterns
- Read the code you're changing before modifying it
- Match naming conventions in surrounding code
- Reuse existing utilities and components
- [Any project-specific rules from CLAUDE.md]

### 3. Commit Messages
We use [conventional commits](https://www.conventionalcommits.org/):
\`\`\`
feat(scope): add new feature          # New functionality
fix(scope): resolve bug               # Bug fix
docs: update documentation            # Docs only
chore: maintenance task               # No user-facing change
\`\`\`

### 4. Submit a Pull Request
\`\`\`bash
git push origin feat/your-feature
gh pr create --title "feat: Description" --body "Closes #N"
\`\`\`

**PR checklist:**
- [ ] Tests pass: `[test_command]`
- [ ] [verify_command] passes (if exists)
- [ ] Commit messages follow conventions
- [ ] One logical change per PR

## Architecture Overview
[Extracted from README.md architecture section, or auto-generated from source tree]

## What We're Looking For
- Bug fixes with test cases
- Documentation improvements
- Performance improvements with benchmarks
- New features (please open an issue first to discuss)

## What We're NOT Looking For
- Style-only changes (unless fixing inconsistencies)
- New dependencies without prior discussion
- Features outside the project's scope

## Code of Conduct
Be respectful. We're all here to build something useful.

## Questions?
Open an [issue](https://github.com/OWNER/REPO/issues) or start a [discussion](https://github.com/OWNER/REPO/discussions).
```

### Step 4: Validate

- Verify all commands in the doc actually work
- Check that file paths mentioned exist
- Ensure the architecture section matches current source tree

### Step 5: Write and Commit

```bash
# Write to project root
write CONTRIBUTING.md

# Suggest commit
git add CONTRIBUTING.md
git commit -m "docs: add CONTRIBUTING.md"
```

## Success Output

```
✓ CONTRIBUTING.md generated

  Detected:
    Language:     Swift 5.9
    Build:        swift build
    Test:         swift test && ./scripts/verify_release.sh
    Commits:      conventional (feat/fix/docs/chore)
    Branches:     feature-branch → PR → squash merge

  Written: CONTRIBUTING.md (87 lines)

  Commit? [Y/n]
```
