# Contributing to [Product]

Thanks for your interest in contributing!

## Development Setup

### Prerequisites
- [Language] [version]+
- [Build tools]

### Clone and Build
```bash
git clone https://github.com/OWNER/REPO.git
cd REPO
[build command]
```

### Run Tests
```bash
[test command]
[verify command]
```

## Making Changes

### 1. Create a Branch
```bash
git checkout main && git pull
git checkout -b feat/your-feature
```

### 2. Follow Existing Patterns
- Read the code you're changing before modifying it
- Match naming conventions in surrounding code
- Reuse existing utilities and components

### 3. Commit Messages
We use [conventional commits](https://www.conventionalcommits.org/):
```
feat(scope): add new feature
fix(scope): resolve bug
docs: update documentation
chore: maintenance task
```

### 4. Submit a Pull Request
```bash
git push origin feat/your-feature
gh pr create --title "feat: Description" --body "Closes #N"
```

**PR checklist:**
- [ ] Tests pass
- [ ] Commit messages follow conventions
- [ ] One logical change per PR

## What We're Looking For
- Bug fixes with test cases
- Documentation improvements
- Performance improvements with benchmarks
- New features (please open an issue first)

## Questions?
Open an [issue](https://github.com/OWNER/REPO/issues).
