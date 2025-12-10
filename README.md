# Clip

**Clip** is a lightweight, always-available macOS menu bar assistant designed for content creators. It bridges the gap between raw assets and finished presentations, serving as a smart clipboard, asset manager, and AI-powered transformation tool.

## Features

### 🖥️ Native macOS Experience
- **Menu Bar App**: Lives in your menu bar (accessory mode), enabling quick access without cluttering your Dock.
- **Floating Panel**: The window stays on top and doesn't disappear when you interact with other apps, making it the perfect sidekick.
- **Mouse Shake Reveal**: Shake your mouse cursor vigorously to instantly bring Clip to the foreground.

### 🗂️ Asset Management ("The Vault")
- **Drag & Drop**: Simply drag images or text into the app to save them instantly.
- **Persistent Storage**: Your assets are saved safely using SwiftData and persist across app launches.
- **Collapsible Folders**: Organize your assets into folders to keep your vault tidy.
- **Compact View**: Switch between a grid view and a compact list view to manage large collections efficiently.
- **Multi-format Export**: Drag assets out to your Desktop, Keynote, PowerPoint, or other apps.

### ⚡ Transformation Tools
Clip automatically detects the content you paste and offers meaningful transformations:
- **Markdown ↔ Tables**: Convert Markdown tables to CSV or TSV for Excel/Google Sheets.
- **Markdown ↔ Rich Text**: Convert Markdown to formatted Rich Text for Apple Notes, Pages, or Mail.
- **Smart Detection**: The app identifies your content type (tables, text) and switches to the correct mode automatically.

## Installation & Running

1. **Clone the repository**
   ```bash
   git clone https://github.com/blacklogos/markutils.git
   cd markutils
   ```

2. **Run the app**
   ```bash
   swift run
   ```

## Usage Tips

- **Toggle the App**: Click the paperclip icon in the menu bar or used the **Mouse Shake** gesture.
- **Import Assets**: Drag files directly from Finder onto the app window.
- **Organize**: Use the "Folder" icon to create new headers and drag items into them.
- **Transform Text**: Paste text into the input area, select your desired transformation, and click the standard copy button or the "Swap" button to reverse the process.

## Contributing

**🤖 AI Agents & Developers:**
Please read [AGENT_RULES.md](AGENT_RULES.md) before making any changes. This project enforces strict regression testing to prevent feature breakage.
