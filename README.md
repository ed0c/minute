<h1 align="center">
  <br>
  <img src="Minute/Assets.xcassets/AppIcon.appiconset/Minute-macOS-Dark-512x512@1x.png" alt="Minute" width="200">
  <br>
  Minute
  <br>
</h1>

<h4 align="center">A local-first macOS meeting capture app that writes deterministic notes into your Obsidian vault.</h4>

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-0B1B2B">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-2E5EAA">
  <img alt="privacy" src="https://img.shields.io/badge/privacy-local--only-1F7A3F">
</p>

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#output-contract">Output Contract</a> •
  <a href="#how-to-build">How to Build</a> •
  <a href="#testing">Testing</a> •
  <a href="#privacy">Privacy</a> •
  <a href="#docs">Docs</a>
</p>

<p align="center">
  <img src="docs/minute.gif" alt="Minute demo" width="820">
</p>

## Install (Homebrew)
```
brew tap roblibob/minute
brew install --cask minute
```

## Install (Manual)
1. Download the latest DMG from GitHub Releases.
2. Open the DMG and drag `Minute.app` into Applications.
3. Launch Minute from Applications.

## Key Features
- Records audio locally (mic + system audio).
- Transcribes locally with Whisper.
- Summarizes locally with Llama (JSON-only output).
- Renders deterministic Markdown using a fixed template.
- Writes notes, audio, and transcript directly into your Obsidian vault.
- Enriches notes with optional screen context captures during recording.
- Live waveform and live transcript during recording.

Output example:
```
---
type: meeting
date: Jan 22, 2026 at 21:46
title: "Zoom Kitten Filter Incident - 27th Judicial District"
source: "Minute"
length: 1m
tags:
---

# Zoom Kitten Filter Incident - 27th Judicial District

## Summary
During a court hearing in the 27th Judicial District, Rod Ponton experienced a persistent Zoom kitten filter on his video feed. Despite attempts to remove it with assistance from his assistant, the issue remained unresolved. The judge highlighted the potential for recording violations and issued a warning about prohibited recordings. No formal decisions were made regarding the filter.

## Decisions

## Action Items
- [ ] Ensure Zoom video settings are configured correctly to prevent filter activation. (Owner: Rod Ponton)

## Open Questions
- What specific steps were taken to remove the filter?

## Key Points
- A Zoom kitten filter was present during the court hearing.
- The judge cautioned against recording the proceedings.
- Mr. Ponton was unable to resolve the filter issue independently.

## Transcript
[[Meetings/_transcripts/2026-01-22 20.45 - Zoom Kitten Filter Incident - 27th Judicial District.md]]

```

## Requirements
- macOS 14+
- Apple Silicon (M1 or newer)

## Privacy
- Audio and inference stay local.
- No outbound network calls except model downloads.

## Contributing
See `CONTRIBUTING.md`.

## Security
See `SECURITY.md`.

## License
MIT. See `LICENSE`.
