# Phase 05 — Export / Import (Multi-Device Portability)

**Status:** pending  
**Parent:** [plan.md](plan.md)  
**GitHub Issue:** blacklogos/markutils#4 (to be created)

---

## Context Links

- `Sources/Models/AssetStore.swift` — vault persistence, already Codable
- `Sources/Models/Asset.swift` — `[Asset]` JSON structure
- `Sources/ClipCLI/main.swift` — CLI entry point (Phase 03)
- `plans/20260405-2145-clip-cli-and-branding/phase-03-cli-commands.md`

---

## Overview

**Date:** 2026-04-06  
**Priority:** High — blocks migration and backup workflows  
**Status:** pending

Asset vault lives at one hardcoded path:
```
~/Library/Application Support/Clip/assets.json
```
No way to move data between Macs, back up, or restore. This phase adds Export/Import as the first portability layer.

---

## Key Insights

1. `[Asset]` is already `Codable` — the JSON file IS the export format. No new serialization needed.
2. Three distinct use cases (backup / migrate / sync) should not be conflated. This phase covers backup + migrate only. Sync is Phase 6 (deferred).
3. CLI is the natural interface for backup automation (cron, scripts). GUI panels handle one-time migrate use case.
4. Images stored as `Data` (base64 in JSON) — export file may be large if vault has many images. Acceptable; document size expectation.
5. Merge vs Replace on import: **Replace** is simpler and safer for v1. Merge introduces ID collision logic. YAGNI.

---

## Requirements

### GUI (App)
- "Export Vault…" menu item → `NSSavePanel` → user picks destination → writes `clip-backup-YYYYMMDD.json`
- "Import Vault…" menu item → `NSOpenPanel` → user picks `.json` → confirmation dialog ("This will replace your current vault. Continue?") → replaces assets

### CLI
- `clip export` → writes current vault JSON to stdout
- `clip import` → reads JSON from stdin, replaces vault
- `clip export --file path/to/backup.json` → writes to file (convenience)
- `clip import --file path/to/backup.json` → reads from file (convenience)

### Shared behavior
- Export: encode `AssetStore.shared.assets` as pretty-printed JSON
- Import: decode, validate (must be `[Asset]`), replace `AssetStore.shared.assets`
- Invalid JSON on import → print error to stderr, exit 2, vault unchanged
- Empty vault export → writes `[]`, exits 0

---

## Architecture

### No new files needed in ClipCore
`AssetStore` already handles encode/decode. Export = `JSONEncoder().encode(assets)`. Import = `JSONDecoder().decode([Asset].self, from: data)` + `store.assets = decoded`.

### GUI additions
- `ContentView` or `AppDelegate` menu: add "Export Vault…" and "Import Vault…" actions
- Use `NSSavePanel` / `NSOpenPanel` (standard AppKit file pickers)
- Confirmation alert before import (destructive action)

### CLI additions to `main.swift`

```swift
case "export":
    // Optional --file flag
    let outputPath = flagValue("--file", in: args)
    let data = try! JSONEncoder().encode(AssetStore.shared.assets)
    if let path = outputPath {
        try! data.write(to: URL(fileURLWithPath: path))
    } else {
        print(String(data: data, encoding: .utf8)!, terminator: "")
    }

case "import":
    let inputPath = flagValue("--file", in: args)
    let data: Data
    if let path = inputPath {
        data = try! Data(contentsOf: URL(fileURLWithPath: path))
    } else {
        data = FileHandle.standardInput.readDataToEndOfFile()
    }
    guard let assets = try? JSONDecoder().decode([Asset].self, from: data) else {
        fputs("clip import: invalid JSON or unrecognized format\n", stderr)
        exit(2)
    }
    AssetStore.shared.assets = assets
    fputs("Imported \(assets.count) asset(s).\n", stderr)
```

Note: `AssetStore` is a singleton with `@Observable` — CLI use requires it to run in a context where `didSet` fires correctly. Verify that `assets.didSet` (which calls `save()`) works in CLI context without a RunLoop. If not, call `store.save()` explicitly after assignment.

### Typical usage patterns

```bash
# Daily backup via cron
0 2 * * * /usr/local/bin/clip export > ~/Dropbox/clip-backup-$(date +%Y%m%d).json

# Migrate to new Mac
clip export > /tmp/clip-vault.json
scp /tmp/clip-vault.json newmac:~/
ssh newmac clip import < ~/clip-vault.json

# Quick restore
clip import < ~/Dropbox/clip-backup-20260406.json
```

---

## Related Code Files

- `Sources/Models/AssetStore.swift:29-45` — `save()`, `load()`, `add()`, `delete()`
- `Sources/Models/Asset.swift` — Codable struct
- `Sources/ClipCLI/main.swift` — add `export` and `import` cases
- `Sources/AppDelegate.swift` — add menu items (or ContentView toolbar)

---

## Implementation Steps

1. **CLI `export` command** — read `AssetStore`, encode, write to stdout or `--file`
2. **CLI `import` command** — read stdin or `--file`, decode, replace vault, verify `save()` fires
3. **Verify `AssetStore` works in CLI context** — no RunLoop required for `save()` (it's synchronous file I/O — should work fine)
4. **GUI Export** — add "Export Vault…" to menu, wire `NSSavePanel`, write JSON
5. **GUI Import** — add "Import Vault…" to menu, `NSOpenPanel` with `.json` filter, confirmation alert, replace vault
6. Smoke test round-trip: `clip export | clip import` (should be identity operation)
7. Smoke test empty vault: `clip export` → `[]`
8. Smoke test invalid import: `echo "garbage" | clip import` → stderr error, exit 2

---

## Todo

- [ ] CLI: `clip export` (stdout)
- [ ] CLI: `clip export --file <path>`
- [ ] CLI: `clip import` (stdin)
- [ ] CLI: `clip import --file <path>`
- [ ] Verify `AssetStore.save()` fires correctly in CLI context
- [ ] GUI: "Export Vault…" menu + NSSavePanel
- [ ] GUI: "Import Vault…" menu + NSOpenPanel + confirmation
- [ ] Round-trip smoke test
- [ ] Error path smoke test (invalid JSON → exit 2)
- [ ] Document in `clip --help`

---

## Success Criteria

- `clip export | clip import` round-trips vault with zero data loss
- Import of invalid JSON exits 2, vault unchanged
- GUI export produces a file that `clip import` can consume
- Image assets survive round-trip (base64 data preserved)

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Large vault (many images) → huge JSON file | Medium | Document; no streaming needed for personal use |
| `AssetStore` singleton not initialized in CLI | Low | `AssetStore.shared` init loads from file — works without UI |
| Import replaces without undo | Medium | Confirmation dialog in GUI; document in CLI `--help` |
| Concurrent write (app + CLI both open) | Low | Last writer wins (same as current behavior); document |

---

## Security Considerations

- Import reads arbitrary JSON files — use `JSONDecoder` with strict type (`[Asset].self`), not `Any`. Malformed input is rejected cleanly.
- No shell execution of imported content.
- Export contains user data (snippets, images) — user is responsible for where they save it.

---

## Deferred (not in this phase)

- **Sync** (iCloud Drive path or Dropbox folder config) → Phase 06 if demand warrants
- **Merge import** (union of two vaults, dedup by ID) → revisit if users request
- **Selective export** (export only selected assets) → YAGNI for now

---

## Next Steps

After CLI commands (Phase 03) are complete, implement CLI export/import first (lower risk), then GUI panels.
