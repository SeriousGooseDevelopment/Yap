# Yap

A voice journal. Tap the mic, talk, and Yap transcribes it on-device with Apple's own
speech recognizer, estimates tone, and tags topics — all fully offline, no account, no
server, no bundled model. The whole app is about 4.5MB.

See `CLAUDE.md` for the app architecture and design history.

## Requirements

- Xcode 26+, iOS 26.0 deployment target (used for system glass buttons and current system
  controls).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- No accounts, no bundled model to download or load. Recording, transcription, mood, and
  topics need no API key and no network access at any point — the one exception is the
  optional "Clean up" action on a saved entry, which needs an NVIDIA API key and a network
  call; see "Clean up (the one network feature)" below.

## Build

```sh
cd /path/to/Yap
cp Yap/AI/Secrets.swift.example Yap/AI/Secrets.swift
# Put your own NVIDIA API key in Yap/AI/Secrets.swift if you want cleanup.
xcodegen generate
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Yap.xcodeproj -scheme Yap -destination 'generic/platform=iOS Simulator' build
```

See `CLAUDE.md` for simulator install/launch, device install, and screenshot recipes.

## How transcription works

Apple's on-device `SFSpeechRecognizer` (see `Speech/Transcriber.swift`) does the whole job —
both the live word-by-word captions while you talk, and the transcript that actually gets
saved (its `isFinal` result once you stop, which resolves any misheard words using the whole
utterance's context). No model to bundle, nothing to load, no wait after Stop beyond a
fraction of a second.

This project used to bundle a bundled Whisper CoreML model via WhisperKit as a second,
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

Mood and topics are derived from that transcript with Apple's on-device `NaturalLanguage`
sentiment analysis and a small keyword classifier — see `Model.swift` and `Store.swift`.
Nothing here calls a paid API or leaves the device.

## Clean up (the one network feature)

Every other feature in this app is 100% on-device — see "How transcription works" above.
The one deliberate exception: a saved entry's detail screen has a "Clean up" button
(`Screens/DetailView.swift`) that, only after a confirmation, sends that entry's text to
NVIDIA's hosted inference API (`AI/JournalSimplifier.swift`) to strip verbal filler — "um,"
"uh," false starts, words repeated mid-sentence — while preserving the speaker's exact
wording. It's a light copy-edit, not a rewrite: no rephrasing, no summarizing, same words
minus the speech artifacts, so a dictated entry reads like it was typed instead of spoken.

The returned version is shown beside the original; the journal changes only if you choose
"Use cleaned version." Nothing is sent automatically, and nothing else in the app makes a
network call. The repository intentionally excludes the real key. For a local build, copy
`Yap/AI/Secrets.swift.example` to `Yap/AI/Secrets.swift` and put your own NVIDIA API key
there; the real file is gitignored.

Get a key at [build.nvidia.com](https://build.nvidia.com). A key embedded in a compiled app
is extractable by anyone with the binary. Never use a personal key in a distributed app;
shipping this feature safely requires a server-side proxy that holds the key.

## Visual system

The journal uses a quiet paper-and-ink palette, readable entry text, and one restrained
blue reserved for actions. The home screen puts recent writing first and keeps "Record a
thought" pinned below the scroll area, so the primary action never covers a note. Journal
and Patterns use the native segmented control; entry details use native navigation and the
system back gesture. Light and dark appearance follow the system. Glass is limited to small
system controls, not used as a surface for journal text.

- **Native controls for native jobs.** A system segmented picker handles section switching;
  glass styling is reserved for compact navigation and playback controls.
- **Estimated mood** uses a muted terracotta → amber → sage ramp, paired with text and
  accessible labels instead of relying on color alone. The analysis is a rough signal, not a
  judgment of the writer's mental state.
- **Patterns** are on-device estimates, not AI-generated conclusions, and appear only after
  enough entries exist to make the estimates more useful.
- **Entries now carry their audio.** `EntryAudioStore` writes each recording to a compressed
  `.m4a` and a downsampled peak-amplitude waveform (`JournalEntry.waveform`, optional — nil
  for the design's seed entries, which have no underlying audio) alongside the transcript.
  `WaveformPlayer` (`Components.swift`) renders that waveform with a play/pause button and a
  drag-to-seek scrub bar, backed by `AudioPlayerController`. Previously the detail screen had
  no visual trace an entry was ever spoken.
- **The recording-idle screen** has a slow breathing radial glow behind the mic button
  (`RecordingView.idleBackground`) instead of a flat blank field — skipped under Reduce
  Motion.
- **Entry rows** are quiet, hairline-separated notes; mood estimates are labeled in text.
  Tag pills use a dedicated background and border so they remain legible in dark mode.
- **Live transcription** lets text arrive plainly, matching familiar system dictation rather
  than adding attention-grabbing per-word animation.

The app icon's voice waveform flows into a written line, a mark made for Yap rather than a
reused journal or food-tracker motif. Amy Food Journal is a reference for note-like clarity
and low-friction logging, not a template: Yap keeps spoken words and their recordings at the
center of its own interface.

Old screenshots from the superseded interface and generated graph-analysis output are
intentionally excluded from the public repository. Regenerate screenshots from a current
device or Simulator build before reviewing final visual polish.

## First launch

A real first launch starts with **zero entries** — no mood grid data, no streak, no
sample journal text. That wasn't always true: the design's 12 seed entries used to write
to disk on every fresh install, so every new user opened the app straight into what read
as someone else's private journal (a "10-day streak" they hadn't earned, mood-trend copy
about days that never happened). Bad first impression for an app whose whole pitch is
on-device privacy, so seed data is now opt-in only, via a DEBUG-only launch argument for
screenshots/demos:

```sh
xcrun simctl launch $SIM com.timothykoelsch.Yap -seedDemo
```

The empty-state copy on both tabs (`DashboardView.emptyState`, `InsightsView`'s existing
`insightCards` guard) is what a genuinely new user sees instead.
