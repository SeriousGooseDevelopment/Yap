import SwiftUI
import PhotosUI

/// Prototype screen 13: the draft from a recording (or an entry being edited), with an
/// editable title and body, Format (Clean Up, bold, italic), a photo, and "Add voice".
struct WritingView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.screen) private var screen
    @State private var controller = RichTextController()
    @State private var pickingPhoto = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var savePops = 0
    @FocusState private var titleFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Palette.screen.ignoresSafeArea()

            if let draft = store.draft {
                ScrollView {
                    page(draft)
                        .padding(EdgeInsets(top: 16, leading: 24, bottom: 150, trailing: 24))
                        .opacity(store.isCleaningUp ? 0.25 : 1)
                        .blur(radius: store.isCleaningUp ? 3 : 0)
                        .animation(.easeInOut(duration: 0.5), value: store.isCleaningUp)
                }
                .scrollDismissesKeyboard(.interactively)
                .padding(.top, screen.y(102))
                .ignoresSafeArea(.container, edges: .top)
            }

            topBar
                .padding(.top, screen.y(54))
                .ignoresSafeArea(.container, edges: .top)

            bottomBar
                .padding(.bottom, keyboardAwareBottom)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { NavigationGate.allowsPop = false }
        .onDisappear { NavigationGate.allowsPop = true }
        .photosPicker(isPresented: $pickingPhoto, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                if let data { store.setDraftPhoto(data) }
                pickerItem = nil
            }
        }
    }

    /// The bottom bar sits 41pt above the screen edge, or just above the keyboard.
    private var keyboardAwareBottom: CGFloat { max(0, screen.bottom(41) - screen.safeBottom) }

    private func page(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let name = draft.photo, let image = PhotoStore.image(name) {
                Color.clear
                    .frame(height: 180)
                    .overlay(Image(uiImage: image).resizable().scaledToFill())
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.bottom, 20)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)), removal: .opacity))
                    .accessibilityLabel("Entry photo")
            }

            Text(Fmt.writingDate(draft.date))
                .font(.sf(14))
                .monospacedDigit()
                .foregroundStyle(Palette.ink2)

            TextField("", text: titleBinding, prompt: Text("Title").foregroundStyle(Palette.placeholder), axis: .vertical)
                .font(.news(34, 500))
                .tracking(-0.51)
                .foregroundStyle(Palette.ink)
                .tint(Palette.yap)
                .focused($titleFocused)
                .submitLabel(.next)
                .padding(.top, 8)
                .accessibilityLabel("Title")

            ZStack(alignment: .topLeading) {
                RichTextEditor(
                    markdown: bodyBinding,
                    revision: store.draftRevision,
                    appendedFrom: draft.appendedFrom,
                    controller: controller
                )
                if InlineMarkdown.plain(draft.body).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Nothing was transcribed. Type here, or tap the mic to keep talking.")
                        .font(.news(RichTextEditor.fontSize))
                        .newsLines(RichTextEditor.fontSize, lineHeight: RichTextEditor.lineHeight)
                        .foregroundStyle(Palette.placeholder)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { store.draft?.title ?? "" },
            set: { value in
                // Return in the title moves on to the body instead of adding a line.
                if value.contains("\n") {
                    store.draft?.title = value.replacingOccurrences(of: "\n", with: "")
                    titleFocused = false
                    controller.focus()
                } else {
                    store.draft?.title = value
                }
                store.draftSaved = false
            }
        )
    }

    private var bodyBinding: Binding<String> {
        Binding(
            get: { store.draft?.body ?? "" },
            set: { value in
                guard store.draft?.body != value else { return }
                store.draft?.body = value
                store.draftSaved = false
            }
        )
    }

    private var topBar: some View {
        HStack {
            BackLink { store.leaveWriting() }
            Spacer()
            Button {
                savePops += 1
                store.saveDraft()
            } label: {
                HStack(spacing: 6) {
                    if store.draftSaved {
                        GlyphView(glyph: .check, size: 15, lineWidth: 2.6)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text(store.draftSaved ? "Saved" : "Save").font(.sf(15, .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 36)
                .background(Capsule().fill(Palette.yap))
                .popOnChange(of: savePops, scale: 1.1)
            }
            .buttonStyle(.press)
            .animation(.easeOut(duration: 0.2), value: store.draftSaved)
            .disabled(store.draftSaved)
        }
        .frame(height: 48)
        .padding(.leading, 12)
        .padding(.trailing, 16)
    }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 0) {
                Menu {
                    Button {
                        store.cleanUpDraft()
                    } label: {
                        Text("Clean Up")
                        Text("Uses a server")
                    }
                    Button("Bold") { format(.yapBold) }
                    Button("Italic") { format(.yapItalic) }
                } label: {
                    barItem(.format, "Format")
                }
                .menuOrder(.fixed)

                if store.draft?.photo == nil {
                    Button {
                        pickingPhoto = true
                    } label: {
                        barItem(.photo, "Photo")
                    }
                    .buttonStyle(.press)
                } else {
                    Menu {
                        Button("Choose Another Photo") { pickingPhoto = true }
                        Divider()
                        Button("Remove Photo", role: .destructive) { store.setDraftPhoto(nil) }
                    } label: {
                        barItem(.photo, "Photo")
                    }
                    .menuOrder(.fixed)
                }
            }
            .frame(height: 62)
            .yapFrost(Capsule())

            RecordButton(label: "Add voice") { origin in
                titleFocused = false
                store.startRecording(.append, from: origin)
            }
        }
        .padding(.horizontal, 20)
    }

    private func barItem(_ glyph: Glyph, _ title: String) -> some View {
        VStack(spacing: 3) {
            GlyphView(glyph: glyph, size: 22, lineWidth: 1.8).foregroundStyle(Palette.ink)
            Text(title).font(.sf(11, .medium)).foregroundStyle(Palette.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func format(_ key: NSAttributedString.Key) {
        if !controller.toggle(key) { store.showToast("Select some text first") }
    }
}

/// Lets a screen turn off the interactive back swipe (the writing screen asks before
/// discarding a new entry, so it can't be swiped away).
enum NavigationGate {
    static var allowsPop = true
}
