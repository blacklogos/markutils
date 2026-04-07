# Phase 04 — Install and Docs

**Status:** pending  
**Parent:** [plan.md](plan.md)

---

## Context Links

- `scripts/verify_release.sh` (existing)
- `Sources/ClipCLI/main.swift` (from Phase 03)

---

## Overview

Provide a simple install script and in-binary `--help` output. No man page, no Homebrew tap (YAGNI). Users can install manually in 2 commands.

---

## Key Insights

1. Target users are macOS developers/content creators — they are comfortable with terminal installs.
2. A shell script wrapping `swift build -c release` + `cp` covers 100% of install needs.
3. Man page overhead (troff formatting, `man` db registration) is not justified for 3 commands. `--help` output in the binary is sufficient.
4. Homebrew tap requires: formula file, GitHub releases with attached binaries, ongoing maintenance. YAGNI until ≥3 external users request it.
5. `/usr/local/bin` is the conventional user-local bin on macOS (writable without sudo on most setups). `/usr/bin` requires SIP bypass — never use.

---

## Requirements

- Install script: `scripts/install_cli.sh`
- Script must: build release binary, detect existing `clip` in PATH and warn, copy to `/usr/local/bin/clip`
- `--help` output built into `main.swift` (already planned in Phase 03)
- No external documentation files beyond this plan

---

## Architecture

### `scripts/install_cli.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

BINARY_NAME="clip"
INSTALL_DIR="/usr/local/bin"
BUILD_CONFIG="release"

echo "Building $BINARY_NAME ($BUILD_CONFIG)..."
swift build -c "$BUILD_CONFIG" --product "$BINARY_NAME"

BUILT_PATH=".build/$BUILD_CONFIG/$BINARY_NAME"

if [ ! -f "$BUILT_PATH" ]; then
    echo "ERROR: Build succeeded but binary not found at $BUILT_PATH" >&2
    exit 1
fi

# Warn if 'clip' already resolves to something else
EXISTING=$(which "$BINARY_NAME" 2>/dev/null || true)
if [ -n "$EXISTING" ] && [ "$EXISTING" != "$INSTALL_DIR/$BINARY_NAME" ]; then
    echo "WARNING: '$BINARY_NAME' already exists at $EXISTING"
    echo "         It will be shadowed by the new install at $INSTALL_DIR/$BINARY_NAME"
    read -r -p "Continue? [y/N] " confirm
    case "$confirm" in
        [yY]) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
fi

echo "Installing to $INSTALL_DIR/$BINARY_NAME..."
mkdir -p "$INSTALL_DIR"
cp "$BUILT_PATH" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "Done. Run: clip --help"
```

### PATH Setup Note (for docs/README or release notes)

If `/usr/local/bin` is not in PATH (rare on modern macOS):
```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

### Uninstall

One line — document in `--help` or release notes:
```bash
rm /usr/local/bin/clip
```

---

## --help Output (already in main.swift from Phase 03)

The `printUsage()` function covers:
- Subcommand list with descriptions
- Example invocations including `pbpaste | clip md2social | pbcopy`
- Note about UTF-8 terminal requirement for `md2social`

No separate man page needed.

---

## Homebrew Tap (Deferred)

Requirements to revisit:
- ≥3 external users requesting it
- Stable binary release artifacts (GitHub Releases with notarized binary)
- Willingness to maintain formula on Swift version bumps

Current effort estimate if/when pursued: ~2 hours (formula, test, tap repo setup).

---

## Related Code Files

- `scripts/install_cli.sh` — new file
- `Sources/ClipCLI/main.swift` — `printUsage()` is the doc surface
- `scripts/verify_release.sh` — existing; may want to add `clip --help` smoke test

---

## Implementation Steps

1. Create `scripts/install_cli.sh` with content above.
2. `chmod +x scripts/install_cli.sh`.
3. Test on clean shell: `bash scripts/install_cli.sh` — verify binary appears in `/usr/local/bin/clip`.
4. Test `clip --help` from a new terminal session.
5. Test `which clip` returns `/usr/local/bin/clip`.
6. Optionally extend `scripts/verify_release.sh` to also build the `clip` product.

---

## Todo

- [ ] Create `scripts/install_cli.sh`
- [ ] `chmod +x scripts/install_cli.sh`
- [ ] End-to-end install test on a clean PATH
- [ ] Verify `clip --help` works post-install
- [ ] Consider: add `swift build --product clip-tool` to `verify_release.sh`

---

## Success Criteria

- `bash scripts/install_cli.sh` completes without error on macOS 14+.
- `clip --help` prints usage without error.
- `clip` binary is ~1–3MB release build (Swift stdlib statically linked where possible).
- Existing `verify_release.sh` still passes (no regression to app build).

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `/usr/local/bin` doesn't exist | Low | `mkdir -p` in script handles it |
| `swift build -c release` slow on first run | Expected | Not a risk — just a UX note |
| User's `clip` alias overrides install | Low | Script warns and prompts |
| Swift runtime not available on target machine | Low | macOS 14 ships Swift runtime; CLI doesn't require Xcode post-install |

---

## Security Considerations

- Script copies binary to `/usr/local/bin`. Does not use `sudo` — if dir is root-owned, script will fail with permission error. User must handle with `sudo cp` manually. Do not auto-escalate.
- Binary makes no network calls, no filesystem writes beyond stdout. No entitlements needed.

---

## Next Steps

After all 4 phases complete:
1. Run `./scripts/verify_release.sh` — must pass.
2. Tag as `v1.2.0` (CLI companion addition = minor version bump).
3. Update release notes to document `clip` CLI availability.
