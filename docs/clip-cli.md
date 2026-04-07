# clip CLI

Command-line companion to the Clip app. Exposes the same text transformers as stdin → stdout pipes, or transforms your clipboard in-place with `--clipboard`.

---

## Install

### From the DMG (recommended)

After mounting `Clip-x.x.x.dmg`:

1. Drag **Clip.app** to Applications as usual.
2. Double-click **"Install CLI.command"** in the same DMG window.
3. Enter your password when prompted (needed to write to `/usr/local/bin`).

That's it — `clip` is now available in your terminal.

### From source

```bash
bash scripts/install_cli.sh
```

If `/usr/local/bin` is not in your PATH (uncommon on macOS):

```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

**Uninstall:**

```bash
sudo rm /usr/local/bin/clip
```

---

## Clipboard flag

Add `-c` or `--clipboard` to any command to read from the clipboard and write the result back:

```bash
clip md2html --clipboard      # transforms clipboard markdown → HTML in-place
clip md2social -c             # style clipboard text for social media
clip html2md --clipboard      # convert clipboard HTML → markdown
```

Result is written back to the clipboard silently. A confirmation line goes to stderr.

---

## Commands

### `md2html` — Markdown → HTML

```bash
echo "# Hello **world**" | clip md2html
clip md2html < README.md > output.html
clip md2html --clipboard
```

Outputs an HTML fragment (no `<html>`/`<head>`/`<body>` wrapper).

---

### `html2md` — HTML → Markdown

```bash
echo "<h1>Hello</h1><p>World</p>" | clip html2md
curl -s https://example.com | clip html2md
clip html2md --clipboard
```

Handles full HTML documents — strips `<head>` and outer structural tags automatically. Tables convert to markdown table syntax.

---

### `md2social` — Markdown → Unicode-styled text

```bash
echo "**bold** and _italic_" | clip md2social
clip md2social --clipboard
```

Converts markdown emphasis to Unicode bold/italic characters (𝗯𝗼𝗹𝗱, 𝘪𝘵𝘢𝘭𝘪𝘤). Useful for LinkedIn, Twitter/X bios, and other platforms that don't render markdown.

Requires a UTF-8 terminal. Output may appear as `?` in legacy terminals.

---

## Composing pipes

```bash
# Markdown file → HTML file
clip md2html < post.md > post.html

# HTML page → clean markdown
curl -s https://example.com | clip html2md

# Social post: write in markdown, paste Unicode
echo "**Big news:** we just shipped v2" | clip md2social | pbcopy
```

---

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success (including empty input) |
| 1 | Unknown subcommand or no arguments |

---

## Help

```bash
clip --help
clip md2html --help
clip html2md --help
clip md2social --help
```

---

## Technical notes

The CLI product is named `clip-tool` internally in `Package.swift` to avoid a [case-insensitive filesystem collision](solutions/build-errors/spm-product-name-collision-case-insensitive-apfs-20260407.md) with the `Clip` app binary. It installs as `clip` for end users.
