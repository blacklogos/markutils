# Product Requirements Document (PRD): Content Creation Assistant

## 1. Executive Summary

**Product Name:** Clip
**Platform:** macOS (Menu Bar App)
**Core Value:** A lightweight, always-available companion for content creators that bridges the gap between raw assets and finished slides/documents. It serves as a smart clipboard, asset manager, and AI-powered transformation tool.

**Current Status:** Phase 1 MVP Complete ✅

## 2. User Personas

- **The Slide Master:** Frequently builds decks in Google Slides/PPT. Needs quick access to icons, logos, and standard text blocks.
- **The Diagrammer:** Creates visuals and needs to rapidly convert text notes into structured tables or diagram-ready formats.
- **The Content Marketer:** Juggles text, images, and formatting for various platforms.

## 3. Functional Requirements

### 3.1. Menu Bar Interface ✅ COMPLETE

- ✅ **Global Toggle:** Click menu bar icon to show/hide
- ✅ **Floating Window/Panel:** Stays on top, doesn't dismiss on interaction
- ✅ **Drag & Drop:** Drag assets to Desktop, Keynote, PowerPoint
- ✅ **No Dock Icon:** True menu bar app (accessory mode)

### 3.2. Asset Management ("The Vault") ✅ COMPLETE

- ✅ **Saved Assets:** Drag images into the app to save
- ✅ **Persistence:** SwiftData storage across app restarts
- ✅ **Delete:** Right-click context menu
- ✅ **Multi-format Export:** PNG, TIFF, JPEG for compatibility
- ⚠️ **Google Slides:** Browser limitation (drag to Desktop first)

### 3.3. Transformation Tools ✅ COMPLETE

**Implemented:**

- ✅ **Markdown ↔ TSV:** For Excel/Google Sheets
- ✅ **Markdown ↔ CSV:** For spreadsheet export
- ✅ **Markdown ↔ Rich Text:** For Notes/Pages with formatting
- ✅ **Smart Detection:** Auto-selects transformation type (⚡ indicator)
- ✅ **Swap Button:** Reverse input/output
- ✅ **Copy Buttons:** Both input and output areas

**Supported Formatting:**

- Headers (# ## ###)
- **Bold**, _Italic_, `Code`
- Lists (- or \*)
- Tables

**Pending:**

- ⏳ **Text-to-Diagram:** Mermaid.js generation, ASCII generation with MonoDraw style
- ⏳ **Image Tools:** Background removal, resize

### 3.4. Autotext / Snippets ⏳ PLANNED

- ⏳ **Text Expansion:** Type keyword to insert snippet
- ⏳ **Dynamic Variables:** Dates, clipboard content

### 3.5. AI Integration ⏳ PLANNED

- ⏳ **Summarization:** Long text → bullet points
- ⏳ **Tone Adjustment:** Formal/casual conversion
- ⏳ **Smart Rewriting:** Content optimization

## 4. Technical Architecture

**Implemented:**

- ✅ **Language:** Swift (SwiftUI + AppKit)
- ✅ **Data Storage:** SwiftData for assets
- ✅ **Window Management:** Custom NSPanel for floating behavior
- ✅ **Drag & Drop:** NSItemProvider with multiple UTTypes
- ✅ **Rich Text:** NSAttributedString with RTF export

**Planned:**

- ⏳ **AI Engine:** TBD (Local CoreML vs Cloud API)
- ⏳ **Accessibility API:** For autotext detection

## 5. Roadmap

### Phase 1: MVP ✅ COMPLETE

- ✅ Menu bar app skeleton
- ✅ Asset Manager (Drag & Drop)
- ✅ Markdown ↔ Table transformer
- ✅ Markdown ↔ Rich Text transformer
- ✅ Smart content detection

### Phase 2: Enhanced UX (NEXT)

Based on research and user feedback:

- 🎯 **Live Preview Mode** (split-view markdown rendering)
- 🎯 **Template Library** (meeting notes, slide outlines, tables)
- 🎯 **Keyboard Shortcuts** (Cmd+B for bold, etc.)
- 🎯 **Markdown Cheatsheet** (quick reference)
- 🎯 **Export Formats** (HTML, PDF)

### Phase 3: Polish, Onboarding & Social Tools (NEXT)

- 🎯 **Onboarding Flow:** New intro screen with "DevUtils" style demo (Copy/Paste examples).
- 🎯 **App Lifecycle:**
  - Open -> Shows app.
  - Click Close -> Minimizes to tray (doesn't quit).
  - Right-click Tray -> Quit option.
- 🎯 **Theming:** Dark / Light / Auto selection.
- 🎯 **Feedback:** Button to email `mtri.vo@gmail.com`.
- 🎯 **Asset UI:** Hover over asset -> Show "Copy" and "Remove" (X) buttons.
- 🎯 **Social Media Formatter:** (New from `code.html`)
  - **Unicode Styling:** Bold, Italic, Script (with Vietnamese support).
  - **Custom Lists:** Bullet points with emojis (✅, 🔸, etc.).
  - **Emoji Toolbar:** Quick access to common social emojis.
  - **Footer Manager:** Auto-append signature/hashtags.

### Phase 4: AI Integration

- ⏳ LLM integration for text summarization
- ⏳ Tone adjustment and rewriting
- ⏳ Image background removal

### Phase 5: Advanced Features

- ⏳ Autotext/Snippets system
- ⏳ Cloud sync (iCloud)
- ⏳ Team sharing of assets

## 6. Competitive Advantages

**Unique Features:**

1. **Smart Detection** - No other tool auto-detects content type
2. **Bidirectional Transforms** - MD ↔ TSV/CSV/Rich (not just one-way)
3. **Asset + Text Integration** - Combined in one app
4. **Menu Bar Convenience** - Always available, never in the way

**Comparison:**

- Typora/MacDown: Better live preview, but no smart detection or transformations
- Marked 2: Preview only, not an editor
- Bear/Ulysses: Full note-taking apps, too heavy for quick tasks
- **Clip**: Lightweight utility focused on content creation workflows

## 7. Open Questions

- **AI Provider:** Local (Ollama/CoreML) vs Cloud (OpenAI/Anthropic)?
  - Recommendation: Start with Cloud (OpenAI) for quality, add local option later
- **Monetization:** Free during beta, consider one-time purchase ($9.99) or subscription ($2.99/mo)
- **Cloud Sync:** Defer to Phase 4, focus on local-first experience

## 8. Success Metrics

**Phase 1 (Current):**

- ✅ App launches and stays in menu bar
- ✅ Drag & drop works reliably
- ✅ Transformations are accurate
- ✅ Smart detection works 90%+ of the time

**Phase 2 (Next):**

- Live preview renders correctly
- Users create 3+ custom templates
- Keyboard shortcuts reduce mouse usage by 50%

## 9. Next Steps

**Immediate Priority:**

1. Implement Live Preview Mode (highest user impact)
2. Add Template Library (addresses "Slide Master" persona)
3. Implement Keyboard Shortcuts (professional workflow)

See [ENHANCEMENTS.md](file:///Users/admin/Desktop/clip/ENHANCEMENTS.md) for detailed feature specifications.
