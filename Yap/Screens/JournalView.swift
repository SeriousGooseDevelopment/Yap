import SwiftUI

/// Prototype screen 10 (and the calendar, screen 15, which opens over it): the week strip,
/// the selected day's entries, and search.
struct JournalView: View {
    var zoom: Namespace.ID
    @EnvironmentObject private var store: Store
    @Environment(\.screen) private var screen
    @FocusState private var searchFocused: Bool
    @State private var dayDirection: CGFloat = 0
    @State private var stripDrag: CGFloat = 0

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: Date()) }
    private var week: [Date] { (0..<7).compactMap { cal.date(byAdding: .day, value: $0 - 6, to: today) } }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.canvas
            topWash

            if store.calendarOpen {
                CalendarView(zoom: zoom)
                    .transition(.modifier(active: ExpandClip(progress: 0), identity: ExpandClip(progress: 1)))
                    .zIndex(1)
            } else {
                journal
                    .opacity(store.searchOn ? 0 : 1)
                    .allowsHitTesting(!store.searchOn)
                    .transition(.opacity)
            }

            header
                .opacity(store.searchOn ? 0 : 1)
                .zIndex(2)

            if store.searchOn {
                SearchOverlay(focused: $searchFocused)
                    .zIndex(3)
            }

            LinearGradient(stops: [.init(color: Palette.canvas.opacity(0), location: 0), .init(color: Palette.canvas, location: 0.7)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
                .zIndex(2)
        }
        .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.25), value: store.searchOn)
        .ignoresSafeArea(.container)
    }

    /// `radial-gradient(100% 30% at 50% 0%, --yap-50, transparent)`
    private var topWash: some View {
        GeometryReader { geo in
            EllipticalGradient(colors: [Palette.yap50, Palette.yap50.opacity(0)], center: .center)
                .frame(width: geo.size.width * 2, height: geo.size.height * 0.6)
                .position(x: geo.size.width / 2, y: 0)
        }
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack {
            Wordmark(size: 38)
            Spacer()
            Button {
                store.searchOn = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { searchFocused = true }
            } label: {
                GlyphView(glyph: .search, size: 20, lineWidth: 2)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.press)
            .accessibilityLabel("Search")
        }
        .frame(height: 48)
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.top, screen.y(54))
    }

    // MARK: Journal

    private var journal: some View {
        ZStack(alignment: .top) {
            Button {
                openCalendar()
            } label: {
                HStack(spacing: 4) {
                    Text(Fmt.monthYear(store.selectedDay)).font(.sf(15, .semibold)).foregroundStyle(Palette.ink)
                    GlyphView(glyph: .chevronDown, size: 14, lineWidth: 2.4).foregroundStyle(Palette.ink2)
                }
            }
            .buttonStyle(.press)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.top, screen.y(112))
            .accessibilityHint("Opens the calendar")

            weekStrip
                .padding(.horizontal, 12)
                .padding(.top, screen.y(142))

            dayHeader
                .padding(.horizontal, 20)
                .padding(.top, screen.y(236))

            entryList
                .padding(.top, screen.y(270))
        }
    }

    private var weekStrip: some View {
        GeometryReader { geo in
            let column = geo.size.width / 7
            let index = CGFloat(week.firstIndex(of: store.selectedDay) ?? 6)
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(Palette.yap)
                    .shadow(color: Palette.yap.opacity(0.4), radius: 8, x: 0, y: 8)
                    .frame(width: 40, height: 40)
                    .offset(x: index * column + (column - 40) / 2, y: 19)
                    .animation(Motion.ios(0.5), value: index)
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        dayColumn(day)
                            .frame(width: column)
                    }
                }
            }
        }
        .frame(height: 80)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.height > 34 { openCalendar() }
                }
        )
        .accessibilityElement(children: .contain)
    }

    private func dayColumn(_ day: Date) -> some View {
        let selected = day == store.selectedDay
        let hasEntries = !store.entries(on: day).isEmpty
        return Button {
            guard !selected else { return }
            dayDirection = day > store.selectedDay ? 1 : -1
            withAnimation(Motion.soft(0.44)) { store.selectedDay = day }
        } label: {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.sf(11, .semibold))
                    .tracking(0.66)
                    .foregroundStyle(selected ? Palette.yap : Palette.ink3)
                Text(day.formatted(.dateTime.day()))
                    .font(.sf(17, selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Color.white : Palette.ink)
                    .frame(width: 40, height: 40)
                    .popOnChange(of: selected, scale: selected ? 1.1 : 1)
                Circle()
                    .fill(hasEntries ? Palette.yap : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressNone)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(hasEntries ? "Has entries" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var dayHeader: some View {
        let entries = store.entries(on: store.selectedDay)
        let title: String = cal.isDateInToday(store.selectedDay) ? "Today"
            : cal.isDateInYesterday(store.selectedDay) ? "Yesterday"
            : store.selectedDay.formatted(.dateTime.weekday(.wide))
        return HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.news(28, 500))
                .tracking(-0.42)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if !entries.isEmpty {
                Text("\(Fmt.count(entries.count, "entry", "entries")) · \(entries.reduce(0) { $0 + $1.minutes }) min")
                    .font(.sf(13))
                    .foregroundStyle(Palette.ink2)
            }
        }
    }

    private var entryList: some View {
        let entries = store.entries(on: store.selectedDay)
        return ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                    EntryRow(entry: entry, zoom: zoom)
                        .transition(.asymmetric(
                            insertion: .offset(x: dayDirection * 30).combined(with: .opacity).animation(Motion.soft(0.44).delay(Double(i) * 0.05)),
                            removal: .identity
                        ))
                }
                if entries.isEmpty {
                    VStack(spacing: 8) {
                        Text("Nothing here yet").font(.news(22, 500)).foregroundStyle(Palette.ink)
                        Text(cal.isDateInToday(store.selectedDay) ? "Tap the mic and talk about anything." : "No entries on this day.")
                            .font(.sf(15))
                            .sfLines(15, lineHeight: 1.45)
                            .foregroundStyle(Palette.ink2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 250)
                    }
                    .padding(.top, 64)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 170, trailing: 16))
        }
        .scrollIndicators(.hidden)
    }

    private func openCalendar() {
        store.calendarDay = store.selectedDay
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.58)) { store.calendarOpen = true }
    }
}

/// One entry in the day list: its time, then a card with title, snippet, length and photo.
struct EntryRow: View {
    let entry: JournalEntry
    var zoom: Namespace.ID
    @EnvironmentObject private var store: Store
    @State private var arrived = true
    @State private var glow = false

    var body: some View {
        let clock = Fmt.clockParts(entry.date)
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(clock.time).font(.sf(15, .semibold)).monospacedDigit().foregroundStyle(Palette.ink)
                if !clock.period.isEmpty {
                    Text(clock.period).font(.sf(11, .medium)).foregroundStyle(Palette.ink3)
                }
            }
            .frame(width: 50, alignment: .trailing)
            .padding(.top, 17)

            Button {
                store.open(entry.id, zoom: true)
            } label: {
                card
            }
            .buttonStyle(.pressSoft)
            .matchedTransitionSource(id: entry.id, in: zoom)
        }
        .opacity(arrived ? 1 : 0)
        .offset(y: arrived ? 0 : -16)
        .scaleEffect(arrived ? 1 : 0.96)
        .onAppear(perform: flashIfNew)
        .onChange(of: store.flashEntryID) { _, _ in flashIfNew() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.displayTitle), \(Fmt.time(entry.date)), \(entry.minutes) minutes")
        .accessibilityHint("Opens the entry")
    }

    private var card: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.displayTitle)
                    .font(.news(19, 500))
                    .tracking(-0.19)
                    .newsLines(19, lineHeight: 1.2)
                    .foregroundStyle(Palette.ink)
                Text(Fmt.snippet(entry.plainText))
                    .font(.sf(14))
                    .sfLines(14, lineHeight: 1.42)
                    .foregroundStyle(Palette.ink2)
                    .padding(.top, 4)
                HStack(spacing: 6) {
                    GlyphView(glyph: .waveSmall, size: 15, lineWidth: 2).foregroundStyle(Palette.yap)
                    Text(Fmt.minutes(entry)).font(.sf(12.5)).foregroundStyle(Palette.ink2)
                }
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)

            if let name = entry.photo, let image = PhotoStore.image(name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 14))
        .yapCard(radius: 22)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.yap.opacity(glow ? 0.22 : 0), lineWidth: 5)
                .padding(-2.5)
        }
    }

    /// A just-saved entry drops into place and glows once.
    private func flashIfNew() {
        guard store.flashEntryID == entry.id, store.path.isEmpty else { return }
        store.flashEntryID = nil
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { arrived = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { arrived = true }
            withAnimation(.easeOut(duration: 0.45).delay(0.3)) { glow = true }
            withAnimation(.easeIn(duration: 1.0).delay(0.75)) { glow = false }
        }
    }
}

/// Search over every entry, replacing the journal's header and list.
struct SearchOverlay: View {
    var focused: FocusState<Bool>.Binding
    @EnvironmentObject private var store: Store
    @Environment(\.screen) private var screen
    @State private var shown = false

    private var results: [JournalEntry] {
        let q = store.query.trimmingCharacters(in: .whitespaces)
        let sorted = store.entries.sorted { $0.date > $1.date }
        guard !q.isEmpty else { return Array(sorted.prefix(6)) }
        return sorted.filter { ($0.displayTitle + " " + $0.plainText).localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        let q = store.query.trimmingCharacters(in: .whitespaces)
        let list = results
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(q.isEmpty ? "Recent" : list.isEmpty ? "No entries match “\(q)”" : Fmt.count(list.count, "result", "results"))
                        .font(.sf(13))
                        .foregroundStyle(Palette.ink2)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 10)
                    if !list.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { i, entry in
                                Button {
                                    focused.wrappedValue = false
                                    store.open(entry.id)
                                } label: {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(entry.displayTitle).font(.news(17.5, 500)).foregroundStyle(Palette.ink)
                                            Text(Fmt.searchMeta(entry)).font(.sf(13)).monospacedDigit().foregroundStyle(Palette.ink2)
                                            Text(q.isEmpty ? Fmt.snippet(entry.plainText, limit: 80) : Fmt.around(entry.plainText, query: q))
                                                .font(.sf(14))
                                                .sfLines(14, lineHeight: 1.4)
                                                .foregroundStyle(Palette.ink2)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                        GlyphView(glyph: .chevronRight, size: 14, lineWidth: 2.4).foregroundStyle(Palette.chevron)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Palette.card)
                                    .overlay(alignment: .bottom) {
                                        if i < list.count - 1 { Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 16) }
                                    }
                                }
                                .buttonStyle(.pressDim)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .yapCard(radius: 24)
                    }
                }
                .padding(EdgeInsets(top: 4, leading: 16, bottom: 340, trailing: 16))
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 14)
            }
            .scrollDismissesKeyboard(.interactively)
            .padding(.top, screen.y(116))

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    GlyphView(glyph: .search, size: 18, lineWidth: 2).foregroundStyle(Palette.ink3)
                    TextField("", text: $store.query, prompt: Text("Search your entries").foregroundStyle(Palette.placeholder))
                        .font(.sf(16.5))
                        .foregroundStyle(Palette.ink)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .focused(focused)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(
                    Capsule()
                        .fill(Palette.card)
                        .shadow(color: Palette.shadow.opacity(0.1), radius: 10, x: 0, y: 8)
                        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 0.5))
                )
                Button("Cancel") {
                    focused.wrappedValue = false
                    store.query = ""
                    store.searchOn = false
                }
                .font(.sf(17))
                .foregroundStyle(Palette.yap)
            }
            .padding(.horizontal, 16)
            .padding(.top, screen.y(56))
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : 56)
            .scaleEffect(x: shown ? 1 : 0.8, anchor: .trailing)
        }
        .onAppear {
            withAnimation(Motion.ios(0.44)) { shown = true }
        }
    }
}

/// The calendar's "expand" entrance: it is revealed downward from the header area, the
/// part it shares with the journal, and collapses back up when closed.
struct ExpandClip: ViewModifier, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.mask(alignment: .top) {
            GeometryReader { geo in
                Rectangle().frame(height: 222 + (geo.size.height - 222) * progress)
            }
        }
    }
}
