# Yap

A voice journal. Tap the mic, talk, and Yap writes it down as you speak with Apple's own
on-device speech recognizer, keeps the recording, and lets you read it back with the
sentence being spoken highlighted. No account, no server, no bundled model.

See `CLAUDE.md` for the app architecture and design history.

## Requirements

- Xcode 26+, iOS 26.0 deployment target.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- No accounts, no bundled model to download or load. Recording and transcription need no
  API key and no network access at any point — the one exception is the optional "Clean Up"
  action on the writing screen, which needs an NVIDIA API key and a network call; see
  "Clean Up (the one network feature)" below.

## Build

```sh
cd /path/to/Yap
cp Yap/AI/Secrets.swift.example Yap/AI/Secrets.swift
# Put your own NVIDIA API key in Yap/AI/Secrets.swift if you want Clean Up.
xcodegen generate
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Yap.xcodeproj -scheme Yap -destination 'generic/platform=iOS Simulator' build
```

The project has two targets: the app, and `YapWidgets`, a widget extension that shows a
recording in progress as a Live Activity on the Lock Screen and in the Dynamic Island.

See `CLAUDE.md` for simulator install/launch, device install, and screenshot recipes.

## What's in the app

The interface follows `Yap Prototype.dc.html` (Claude Design project "Yap codebase audit
request"), screen for screen:

- **Onboarding** — welcome, "Just talk", "Private by design", your name, microphone and
  speech permission, a daily reminder (morning, evening or a custom time), an optional
  Face ID lock, and "You're all set".
- **Journal** — the last seven days in a strip, the selected day's entries as cards (time,
  title, snippet, length, photo), and search across every entry. Pull the week strip down,
  or tap the month, for the **calendar**: a 17-week heat map of entries and that day's list.
- **Recording** — opens as "Listening…" with a live level meter, turns into the live
  transcript once you start talking, and can be paused, discarded or stopped. Recording
  continues with the phone locked, shown as a Live Activity with a Stop button.
- **Writing** — the transcript becomes a draft with a title. Edit it, bold or italicize a
  selection, add a photo, add more voice, or Clean Up spoken filler.
- **Reading** — the entry with its photo and recording: scrub, ±15s, 0.75×–2× speed, and
  "follow along", which highlights and scrolls to the sentence being played. Tap a sentence
  to play from it. Share the text, the recording or a Markdown file.
- **Insights** — entries, minutes spoken and the current streak for the week, month or
  year, your longest entry, when you usually journal, and recurring themes with a quote.
- **Settings** — name, reminder time, Clean Up permission, appearance, Face ID lock and
  app-switcher privacy, export (Markdown, PDF or plain text), help, and delete all.

## How transcription works

Apple's on-device `SFSpeechRecognizer` (see `Speech/Transcriber.swift`) does the whole job —
both the live word-by-word captions while you talk, and the transcript that actually gets
saved. No model to bundle, nothing to load, no wait after Stop beyond a fraction of a
second.

This project used to bundle a Whisper CoreML model via WhisperKit as a second,
more-accurate pass. Two revisions of that, both removed: `distil-whisper_distil-large-v3`
(~594MB) crashed a real iPhone 12 (4GB RAM) into a full hard reboot on first launch — despite
the "distil" name, only its decoder was distilled, so its encoder was the full 32-layer
large-v3 encoder (339MB alone), and loading/ANE-compiling that was enough memory pressure to
take down the whole device, not just the app. `openai_whisper-base.en` (~144MB) replaced it
and loaded safely, but still cost a multi-second wait after every Stop and ~150MB of app
storage for accuracy gains that turned out to be marginal over Apple's own recognizer. Gone
now, along with the WhisperKit dependency entirely — if bundling any model again, verify it
on the actual lowest-RAM target device first, ideally on a charger, since a bad load can
crash the whole device rather than just the app.

Mood, topics and Insights themes are derived from the transcript with Apple's on-device
`NaturalLanguage` sentiment analysis and a small keyword classifier — see `Model.swift` and
`State/InsightsData.swift`. Nothing here calls a paid API or leaves the device.

## Clean Up (the one network feature)

Every other feature in this app is on-device. The one deliberate exception: the writing
screen's Format menu has "Clean Up", which sends that entry's text to NVIDIA's hosted
inference API (`AI/JournalSimplifier.swift`) to strip verbal filler — "um," "uh," false
starts, words repeated mid-sentence — while preserving the speaker's exact wording.

Nothing is sent until you allow it: either in Settings › Voice & Transcription ("Clean Up
allowed"), or from the prompt the first time you choose Clean Up, which explains what is
sent. The cleaned text replaces the text on the writing screen, where you can keep editing
it, and is saved with the entry like any other edit. The repository intentionally excludes the real key. For a local build, copy
`Yap/AI/Secrets.swift.example` to `Yap/AI/Secrets.swift` and put your own NVIDIA API key
there; the real file is gitignored.

Get a key at [build.nvidia.com](https://build.nvidia.com). A key embedded in a compiled app
is extractable by anyone with the binary. Never use a personal key in a distributed app;
shipping this feature safely requires a server-side proxy that holds the key.

## Visual system

- **Type**: Newsreader (variable, SIL Open Font License, `Yap/Fonts`) for the italic "yap"
  wordmark, titles and entry text; SF Pro for everything else. Each size sets Newsreader's
  weight and optical-size axes explicitly, as browsers do from the CSS pixel size.
- **Color**: one accent blue (`#2F6BF2`) with its tints, ink `#0D1B2E`, cool canvas
  `#F5F7FB` behind white cards. The prototype is light-only; the dark palette is this app's
  own and follows the same hierarchy. Appearance follows the system unless set in Settings.
- **Icons** are the prototype's own SVG paths, drawn by `Shared/SVGPath.swift`.
- **Motion** follows the prototype: staggered fade-ups, the circular reveal from the record
  button, the zoom from a journal card into the entry, the island-shaped toast. Reduce
  Motion turns the decorative loops off.
- **System components** where the prototype imitates them: alerts, menus, the time-picker
  sheet and the share sheet are native, so they get the system's behavior and accessibility.

## First launch

A real first launch starts with **zero entries** — no sample journal text. The design's
sample entries are opt-in only, via a DEBUG-only launch argument for screenshots/demos:

```sh
xcrun simctl launch $SIM com.timothykoelsch.Yap -seedDemo -skipOnboarding
```
