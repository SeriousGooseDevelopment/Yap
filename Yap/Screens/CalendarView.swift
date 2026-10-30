import SwiftUI

/// Prototype screen 15: a 17-week heat map of entries, and the selected day's list.
struct CalendarView: View {
    var zoom: Namespace.ID
    @EnvironmentObject private var store: Store
    @Environment(\.screen) private var screen
    @State private var shakes = 0
    @State private var direction: CGFloat = 0
    @State private var pops: [Int: Int] = [:]

    private let grid = HeatGrid()

    var body: some View {
        let selectedIndex = grid.index(of: store.calendarDay) ?? grid.index(of: grid.today) ?? 0
        let dayEntries = store.entries(on: store.calendarDay)
        ZStack(alignment: .top) {
            monthRow
                .padding(.leading, 20)
                .padding(.trailing, 16)
                .padding(.top, screen.y(110))

            heatCard(selected: selectedIndex)
                .padding(.horizontal, 16)
                .padding(.top, screen.y(162))
                .staggerIn(0, delay: 0.11, distance: -22)

            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.longDay(store.calendarDay)).font(.sf(15, .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                if !dayEntries.isEmpty {
                    Text(Fmt.count(dayEntries.count, "entry", "entries")).font(.sf(13)).foregroundStyle(Palette.ink2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, screen.y(389))
            .staggerIn(1, delay: 0.11, distance: -22)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(dayEntries.enumerated()), id: \.element.id) { i, entry in
                        Button {
                            store.open(entry.id)
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.displayTitle).font(.news(17.5, 500)).foregroundStyle(Palette.ink).lineLimit(1)
                                    Text("\(Fmt.time(entry.date)) · \(Fmt.minutes(entry))")
                                        .font(.sf(13)).monospacedDigit().foregroundStyle(Palette.ink2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                GlyphView(glyph: .chevronRight, size: 14, lineWidth: 2.4).foregroundStyle(Palette.chevron)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 72)
                            .background(Palette.card)
                            .overlay(alignment: .bottom) {
                                if i < dayEntries.count - 1 { Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 16) }
                            }
                        }
                        .buttonStyle(.pressDim)
                        .transition(.asymmetric(insertion: .offset(x: direction * 30).combined(with: .opacity), removal: .identity))
                    }
                    if dayEntries.isEmpty {
                        Text("No entries on this day")
                            .font(.sf(15))
                            .foregroundStyle(Palette.ink3)
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                            .padding(.horizontal, 16)
                            .background(Palette.card)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .yapCard(radius: 24)
                .padding(EdgeInsets(top: 0, leading: 16, bottom: 170, trailing: 16))
            }
            .scrollIndicators(.hidden)
            .padding(.top, screen.y(419))
            .staggerIn(1, delay: 0.11, distance: -22)
        }
    }

    private var monthRow: some View {
        HStack {
            Button(action: close) {
                HStack(spacing: 6) {
                    Text(Fmt.monthYear(store.calendarDay))
                        .font(.news(26, 500))
                        .tracking(-0.39)
                        .foregroundStyle(Palette.ink)
                    GlyphView(glyph: .chevronDown, size: 14, lineWidth: 2.4)
                        .rotationEffect(.degrees(180))
                        .foregroundStyle(Palette.ink2)
                }
            }
            .buttonStyle(.press)
            .shake(shakes)
            .accessibilityHint("Closes the calendar")
            Spacer()
            HStack(spacing: 8) {
                monthButton(-1)
                monthButton(1)
            }
        }
        .frame(height: 40)
    }

    private func monthButton(_ step: Int) -> some View {
        Button {
            moveMonth(step)
        } label: {
            GlyphView(glyph: step < 0 ? .chevronLeft : .chevronRight, size: 16, lineWidth: 2.2)
                .foregroundStyle(Palette.ink)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.press)
        .accessibilityLabel(step < 0 ? "Previous month" : "Next month")
    }

    private func heatCard(selected: Int) -> some View {
        let counts = (0..<grid.cellCount).map { i in grid.isFuture(i) ? -1 : store.entries(on: grid.date(i)).count }
        let total = counts.filter { $0 > 0 }.reduce(0, +)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(row == 1 ? "Mon" : row == 3 ? "Wed" : row == 5 ? "Fri" : "")
                            .font(.sf(11))
                            .foregroundStyle(Palette.ink3)
                            .frame(height: 15)
                    }
                }
                .frame(width: 24, alignment: .leading)
                .padding(.top, 21)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 3) {
                        ForEach(0..<HeatGrid.weeks, id: \.self) { week in
                            Text(monthLabel(week))
                                .font(.sf(11, .medium))
                                .foregroundStyle(Palette.ink2)
                                .fixedSize()
                                .frame(width: 15, height: 13, alignment: .leading)
                        }
                    }
                    HStack(spacing: 3) {
                        ForEach(0..<HeatGrid.weeks, id: \.self) { week in
                            VStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { row in
                                    cell(week * 7 + row, count: counts[week * 7 + row], selected: selected)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text("\(Fmt.count(total, "entry", "entries")) since \(grid.start.formatted(.dateTime.month(.wide)))")
                    .monospacedDigit()
                Spacer()
                HStack(spacing: 3) {
                    Text("Less").padding(.trailing, 3)
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Self.level(level)).frame(width: 15, height: 15)
                    }
                    Text("More").padding(.leading, 3)
                }
                .accessibilityHidden(true)
            }
            .font(.sf(12))
            .foregroundStyle(Palette.ink2)
            .padding(.top, 14)
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
        .yapCard(radius: 26)
    }

    private func cell(_ index: Int, count: Int, selected: Int) -> some View {
        let isSelected = index == selected
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(count < 0 ? Color.clear : Self.level(min(count, 4)))
            .frame(width: 15, height: 15)
            .overlay {
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .strokeBorder(Palette.ink, lineWidth: 1.5)
                    .padding(-3)
                    .opacity(isSelected ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: isSelected)
            }
            .popOnChange(of: pops[index, default: 0], scale: 1.4)
            .contentShape(Rectangle())
            .onTapGesture {
                guard count >= 0, !isSelected else { return }
                direction = index > selected ? 1 : -1
                pops[index, default: 0] += 1
                withAnimation(Motion.soft(0.44)) { store.calendarDay = grid.date(index) }
            }
            .accessibilityElement()
            .accessibilityLabel(grid.date(index).formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .accessibilityValue(count < 0 ? "" : Fmt.count(count, "entry", "entries"))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityHidden(count < 0)
    }

    private func monthLabel(_ week: Int) -> String {
        let month = Calendar.current.component(.month, from: grid.date(week * 7))
        let previous = week == 0 ? -1 : Calendar.current.component(.month, from: grid.date((week - 1) * 7))
        return month == previous ? "" : grid.date(week * 7).formatted(.dateTime.month(.abbreviated))
    }

    static func level(_ n: Int) -> Color {
        switch n {
        case 0: return Palette.heatEmpty
        case 1: return Palette.yap200
        case 2: return Palette.yapMid
        case 3: return Palette.yap
        default: return Palette.yapDeep
        }
    }

    private func moveMonth(_ step: Int) {
        let cal = Calendar.current
        guard let target = cal.date(byAdding: .month, value: step, to: store.calendarDay) else { return }
        let first = grid.date(0)
        // Out of the heat map's range: same month as its first/last day is the limit.
        if target > grid.today && !cal.isDate(target, equalTo: grid.today, toGranularity: .month)
            || target < first && !cal.isDate(target, equalTo: first, toGranularity: .month) {
            shakes += 1
            return
        }
        let clamped = min(max(target, first), grid.today)
        direction = CGFloat(step)
        withAnimation(Motion.soft(0.44)) { store.calendarDay = cal.startOfDay(for: clamped) }
    }

    private func close() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let days = cal.dateComponents([.day], from: store.calendarDay, to: today).day, (0...6).contains(days) {
            store.selectedDay = store.calendarDay
        }
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.5)) { store.calendarOpen = false }
    }
}
