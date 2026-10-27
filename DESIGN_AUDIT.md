# Yap — visual and interaction audit

## Executive assessment

Yap has a clear product advantage: it turns spoken reflection into a private, editable
written record, with the original audio available later. Its visual identity should make the
person's words feel like the product—not charts, AI decoration, or generic dashboard chrome.

The earlier screens had a strong functional core but were not yet a finished, award-level
experience. The main issues were faint small text, a floating microphone covering journal
content, an empty-looking recording state, color-only mood signals, an undifferentiated
solid-blue icon, and analytics language that implied more intelligence and certainty than
the deterministic on-device heuristics provided. This pass addresses those issues in source
and sets a more coherent direction. The result is a substantially better design foundation,
not a claim that the app is ready for an Apple Design Award submission.

**Current status: implementation direction improved; visual verification outstanding.** The
screenshots in `screenshots/` predate this pass. This machine has Apple's Command Line Tools
but not the full Xcode installation, so the modified app could not be built or launched in
Simulator. Layout, status-bar behavior, Dynamic Type, and contrast need confirmation from
fresh screenshots on real iOS rendering before calling the visual audit closed.

## Scope and method

Reviewed the existing light/dark screenshots and app icon, then inspected the SwiftUI views,
theme, entry and sentiment models, accessibility hooks, recording/editing flows, app target
configuration, and project documentation. The screenshot evidence is useful for the earlier
interface only; post-change findings below distinguish source-level improvements from items
that still require runtime inspection.

This is a product and craft review, not a guarantee of award selection. Apple's Design Awards
recognize work across multiple categories; the practical implication here is to pursue a
distinctive, cohesive, useful experience—not to imitate past winners. [Apple Design Awards](https://developer.apple.com/design/awards/)

## Design direction

**Paper and ink; voice becoming a note.** Keep a warm, quiet writing surface, high-contrast
transcript, and one restrained action color. Put entries ahead of their analysis. Keep the
recording action available without floating it over the content. Give Patterns a clear,
secondary home and describe its outputs as rough on-device estimates. Use native iOS controls
where users expect system behavior, and let system appearance, text sizing, contrast, and
Reduce Motion preferences lead.

Amy Food Journal is a useful benchmark for the *clarity* of note-like logging: the user's
record is the main interface, not a stack of cards. Its own site describes this note-like
approach. Yap borrows that principle, not Amy's food-specific layout, identity, or mascot;
Yap's signature is the transformation from voice to an editable journal entry. [Amy Food Journal](https://www.amyfoodjournal.com/), [Amy logging guide](https://www.amyfoodjournal.com/help/logging-food)

## Findings and disposition

| Priority | Finding in the earlier pass | Change in this pass | Status |
|---|---|---|---|
| High | Small secondary labels used translucent system gray; some fell below WCAG AA contrast. | Replaced with explicit paper/ink tokens. Light secondary text is about 5.1:1 against the paper surface; dark secondary text is about 9.4:1 against the dark surface. | Source updated; verify rendered values in both appearances. |
| High | Floating record control obscured journal rows while scrolling. | Replaced with a full-width, 54-point “Record a thought” action pinned below the scroll content. | Source updated; verify on small and large phones. |
| High | Home screen made the mood grid compete with the actual journal. | Recent entries now lead; “Patterns” is a separate native section. | Source updated. |
| High | “AI Insights” presentation overstated deterministic sentiment and keyword heuristics. | Renamed to “Patterns,” disclosed that the read is rough and on-device, and withholds generated pattern copy until five entries exist. Removed gradient/AI signaling. | Source updated; heuristic limitations remain. |
| High | Mood labels such as “Anxious” or “Stressed” sounded diagnostic, and color carried too much meaning. | Uses descriptive estimates (“Very positive,” “Positive,” “Steady,” “Mixed,” “Heavy”), muted color plus text, and spoken date/tone descriptions. The 14-day grid averages all entries for a day rather than silently selecting the newest. | Source updated; validate with VoiceOver and real data. |
| High | “Clean up” sent intimate journal text to an online service without first explaining the transfer; a response could replace the note without review. | Confirmation names NVIDIA and the outbound text; the cleaned result is compared with the original and applied only after an explicit choice. | Source updated; confirm the provider's current data handling before distribution. |
| High | The icon was a solid blue square with no recognizable Yap mark. | Added a custom waveform that resolves into written lines, on the app's paper-and-ink palette. Preserved the old image and references the new opaque 1024×1024 RGB asset in the catalog. | Asset inspected; confirm the compiled icon in the Home Screen and App Store asset workflow. |
| Medium | Custom section tabs lacked native segmented-control semantics and familiar focus behavior. | Replaced the custom gesture control with SwiftUI's native segmented picker and theme tint. | Source updated; verify VoiceOver and selection contrast. |
| Medium | A manual light/dark switch could disagree with the system and duplicate iOS appearance controls. | Normal app launches now inherit system appearance; the debug-only `-dark` launch argument remains for captures. | Source updated; confirm status bar and system surfaces in dark mode. |
| Medium | A day-based streak can feel punitive in a reflective product and count today as missed before the day is over. | Removed the home-screen streak and its unused derived state; the header stays focused on the date and writing. | Source updated. |
| Medium | Recording's idle view looked unfinished and did not explain what to do or where transcription happened. | Added a short prompt, review/edit expectation, and on-device transcription disclosure; reduced the former empty-state void. | Source updated; vertical balance still needs fresh screenshots. |
| Medium | Motion and tiny fixed decorative type did not consistently respect user preferences. | Reduced-motion handling now removes overlay, pulse, waveform, and transcript-follow animation; live waveform bars stay static, and the empty-state symbol uses a semantic text style. | Source updated; inspect all live-recording states with Reduce Motion on. |
| High | The microphone and stop/saved glyphs were forced white on every control tint, including pale dark-mode blue and bright status colors. | Recording controls now choose a high-contrast dark or light glyph for each phase and appearance. | Source updated; confirm with Increase Contrast and actual system button rendering. |
| Medium | Waveform seeking depended on dragging and was not adjustable through VoiceOver. | Added a 44-point playback control and adjustable playback-position action/value. | Source updated; verify increments and spoken labels on device. |
| Medium | Topic matching used substring search and included demo people's names, so ordinary words or private sample names could skew tags. | Uses whole-word/phrase boundaries and removes the sample names from the classifier vocabulary. | Source updated; no classifier accuracy study performed. |
| Medium | Sentiment lookup sampled only the first paragraph, so “continue this entry” could make later words invisible to its mood estimate. | Scores every paragraph and averages by word count. | Source updated; validate with representative language and edge cases. |
| Medium | Clearing a transcript and leaving the editor deleted the entry and audio without a confirmation. | The existing deletion confirmation is now requested when an edit ends empty. | Source updated; verify keyboard dismissal and cancel behavior. |
| Medium | Entry detail used a custom overlay that omitted the system back affordance and edge-swipe behavior. | Detail now lives in a `NavigationStack` with native toolbar actions; the recording screen remains above the stack so continuation still returns to the same entry. | Source updated; verify interactive pop, deletion, and continued recording in Simulator. |

## Screen-by-screen review

### Journal

- **Hierarchy:** The app name and date establish context; “Recent entries” and the user's own
  transcript become the visual focus. The streak prompt was removed: reflective writing
  should not turn missed days into failure or imply a current-day entry before one exists.
- **Rows:** Plain text with generous vertical separation suits a journal better than a stack
  of rounded cards. The excerpt is limited to three lines to keep scanning fast; opening the
  row reveals the complete editable text. Relative date and estimated tone remain visible,
  with audio presence indicated by a waveform glyph.
- **Primary action:** “Record a thought” stays in a bottom safe-area inset, leaving the
  scrollable notes clear. Its large labeled target is more discoverable and safer than an
  unlabeled floating circle.
- **Empty state:** The copy explains what the product does and states the on-device
  transcription promise. The record CTA remains the obvious next action.
- **Consistency cues:** No streak is shown. This keeps the home screen focused on writing
  rather than attendance and avoids a day-boundary count that can feel inaccurate or punitive.

### Patterns

- **Mood rhythm:** Fourteen dated cells use a daily average and muted fill; shape symbols,
  a visible three-item key, and full date/tone VoiceOver descriptions prevent color-only
  interpretation. The left caption correctly names the first day in the 14-cell span as
  “13 days ago.”
- **Topics:** Counts are primary, with bars explicitly described as relative to the most
  mentioned topic. The tone under each topic is labeled estimated, not causal.
- **Generated copy:** Pattern sentences are deterministic templates, not generative AI.
  Their heading and explanation now say so, and the low-sample state avoids manufacturing
  insight from a brand-new journal.
- **Remaining risk:** The mood score still represents wording, not a validated measure of
  wellbeing. Keep the caveat adjacent to the chart and never use the colors or wording to
  diagnose, recommend treatment, or imply cause.

### Recording

- **Idle:** “What’s on your mind?” gives a soft invitation without instructions overload.
  Privacy and transcript-review expectations are stated before the microphone is pressed.
- **Active:** The transcript uses familiar, plain typography; real captured sound drives the
  waveform; time and “Listening” status communicate the recording state. A destructive
  cancel asks before discarding words already captured. Stop, processing, and saved states
  have labels rather than relying on the icon alone. Glyphs now use dark ink on the light
  blue/status tints and light ink on dark processing controls, instead of white everywhere.
- **Motion:** The breathing background, waveform interpolation, word arrival, and modal
  motion must all be checked with Reduce Motion. Source now suppresses the most visible
  animation, but only an on-device run can confirm no motion remains surprising.
- **Remaining risk:** Verify that the live transcript stays readable at the largest Dynamic
  Type sizes, does not jump unexpectedly as words wrap, and stays clear of the bottom action
  on the smallest supported iPhone.

### Entry detail and editing

- **Reading:** Date, saved audio, estimated tone/topics, and the editable transcript are
  distinct; transcript text remains the dominant surface. Native text editing, selection,
  caret visibility, and scaled type are preferable to decorative selection chrome.
- **Privacy:** The online text cleanup is opt-in, disclosed before transmission, and
  reversible in the sense that the original remains until the user accepts the preview.
- **Destructive actions:** Delete explains that the saved audio is also removed. Emptying an
  entry asks for confirmation rather than silently removing it.
- **Navigation:** Detail now uses a native `NavigationStack` destination and system toolbar,
  including the expected back affordance and interactive back gesture. The recording screen
  remains layered above the stack so “Continue this entry” can record without losing the
  current destination.
- **Remaining risk:** Verify interactive pop, deletion-driven dismissal, keyboard dismissal,
  VoiceOver focus order, and toolbar behavior at accessibility text sizes on an iPhone.

### App icon and system appearance

The new mark has a single silhouette and clear voice-to-writing idea, rather than relying on
a tiny wordmark. It uses no alpha channel, satisfying the opaque icon asset convention.
Inspect at actual Home Screen size, tinted icon appearance, and against adjacent app icons;
the mark should still read when reduced substantially. In light and dark appearances, verify
status-bar contrast, material controls, text contrast, and any OS-provided surfaces together.

## Accessibility and craft checklist

- **Contrast:** New light tokens: paper `#F7F6F1`, primary ink `#242A27` (about 13.5:1),
  secondary ink `#626B65` (about 5.1:1), accent `#3F6687` (about 5.6:1). New dark tokens:
  background `#151A17`, primary `#F3F2EB` (about 15.7:1), secondary `#B7C0B9` (about
  9.4:1), accent `#8EB6D6` (about 8.2:1). Ratios are sRGB calculations against the stated
  background, not a substitute for checking overlays and disabled states. Earlier gray
  labels at roughly 60% and 30% opacity over white were about 3.4:1 and 1.7:1—too faint for
  ordinary small text. Apple's guidance calls for sufficient contrast and not using color
  as the only signal. [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
- **Targets:** Main record action is 54 points; circular buttons and audio play are 44
  points. Check the effective hit region after modifiers and on-device rendering.
- **Dynamic Type:** Most SwiftUI text uses semantic styles; the transcript editor uses
  `@ScaledMetric` and adjusts for content size. Stress-test the largest accessibility sizes,
  especially the header, segmented picker, chart grid, cleanup toolbar, and two-button
  review sheet. [Typography](https://developer.apple.com/design/human-interface-guidelines/typography/)
- **VoiceOver:** Journal rows are combined with an open/edit hint; mood cells have localized
  date and estimate descriptions; waveform playback is adjustable. Audit order, focus
  restoration after sheets, and whether state changes are announced without repeating the
  entire transcript.
- **Reduce Motion:** Recording and overlay animation now respond to the system setting.
  [Motion](https://developer.apple.com/design/human-interface-guidelines/motion/)
- **System appearance:** The app follows iOS appearance instead of introducing a competing
  manual toggle, consistent with Apple's dark-mode guidance. [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode/)
- **Native navigation and controls:** Apple's layout guidance emphasizes hierarchy and
  adaptation; segmented controls suit switching among related views. [Layout](https://developer.apple.com/design/human-interface-guidelines/layout/), [Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls/)
- **AI / privacy claims:** Apple advises transparency about generated output and data use.
  Yap's mood/topic heuristics are not generative AI and are now described as estimates; the
  one online cleanup action is disclosed before sending. [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai/)
- **Icon:** Verify the icon at real display sizes and in system contexts, not only at 1024 px.
  [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons/)

## Next verification pass

1. Build and launch from Xcode; resolve compile or asset-catalog diagnostics before any
   visual sign-off. This pass could not do that because full Xcode is not installed here.
2. Capture fresh screens for a new journal, populated journal, recording idle/active/saved,
   detail/edit/audio, cleanup disclosure/result, and Patterns with sparse and dense data.
3. Inspect light, dark, Increase Contrast, largest Dynamic Type, Reduce Motion, VoiceOver,
   keyboard-visible, and small-device layouts. Confirm status-bar and sheet behavior.
4. Test edge-swipe/back navigation, interrupted recording, empty transcript confirmation,
   multiple recordings on one day, and Pattern values using real local entries.
5. Replace stale screenshots only after those checks; retain the source audit and record
   any remaining issue with a screenshot and exact reproduction steps.

Until steps 1–4 pass, this is a strong visual direction and source-level improvement—not a
verified release build or an award-readiness certification.
