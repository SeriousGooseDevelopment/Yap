import SwiftUI

/// The reminder time picker: hour, five-minute and AM/PM wheels in a floating sheet with
/// Cancel and Done, as in the prototype's time sheet.
struct TimeWheelSheet: View {
    var title: String
    var initial: Preferences.ClockTime
    /// Offers "Turn Off Reminders" when reminders are already on.
    var canTurnOff = false
    var onDone: (Preferences.ClockTime) -> Void
    var onTurnOff: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var hour = 9
    @State private var minute = 0
    @State private var pm = true

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.sf(17))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 80, alignment: .leading)
                Spacer()
                Text(title).font(.sf(17, .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                Button("Done") {
                    let h24 = (hour % 12) + (pm ? 12 : 0)
                    onDone(Preferences.ClockTime(hour: h24, minute: minute))
                    dismiss()
                }
                .font(.sf(17, .semibold))
                .foregroundStyle(Palette.yap)
                .frame(width: 80, alignment: .trailing)
            }
            .frame(height: 48)
            .padding(.horizontal, 20)
            .padding(.top, 14)

            HStack(spacing: 4) {
                Picker("Hour", selection: $hour) {
                    ForEach(1...12, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Minute", selection: $minute) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
                Picker("AM or PM", selection: $pm) {
                    Text("AM").tag(false)
                    Text("PM").tag(true)
                }
            }
            .pickerStyle(.wheel)
            .font(.sf(23))
            .monospacedDigit()
            .frame(height: 220)
            .padding(.horizontal, 12)

            if canTurnOff {
                Button("Turn Off Reminders", role: .destructive) {
                    onTurnOff()
                    dismiss()
                }
                .font(.sf(17))
                .foregroundStyle(Palette.danger)
                .frame(height: 44)
            }
        }
        .padding(.bottom, 20)
        .presentationDetents([.height(canTurnOff ? 360 : 316)])
        .presentationCornerRadius(40)
        .presentationDragIndicator(.visible)
        .onAppear {
            hour = initial.hour % 12 == 0 ? 12 : initial.hour % 12
            minute = min(55, Int((Double(initial.minute) / 5).rounded()) * 5)
            pm = initial.hour >= 12
        }
    }
}
