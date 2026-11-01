import SwiftUI

enum Palette {
    static let ink = Color(red: 0.09, green: 0.22, blue: 0.20)
    static let muted = Color(red: 0.44, green: 0.49, blue: 0.46)
    static let background = Color(red: 0.97, green: 0.965, blue: 0.945)
    static let green = Color(red: 0.13, green: 0.35, blue: 0.29)
    static let mint = Color(red: 0.86, green: 0.93, blue: 0.88)
    static let orange = Color(red: 0.84, green: 0.48, blue: 0.26)
    static func routine(_ key: String) -> Color {
        switch key {
        case "orange": orange
        case "blue": Color(red: 0.34, green: 0.49, blue: 0.65)
        case "purple": Color(red: 0.57, green: 0.46, blue: 0.65)
        default: green
        }
    }
}

enum DurationText {
    static func short(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        if seconds > 0 && minutes == 0 { return "1分未満" }
        if minutes < 60 { return "\(minutes)分" }
        let remainder = minutes % 60
        return "\(minutes / 60)時間" + (remainder == 0 ? "" : "\(remainder)分")
    }
    static func clock(_ seconds: Int) -> String {
        let value = max(seconds, 0)
        return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
    }
}

extension View {
    func cardStyle() -> some View {
        self.padding(20)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.ink.opacity(0.06), lineWidth: 1))
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Palette.muted) }
        }
    }
}

struct HabitIcon: View {
    let routine: Routine
    var body: some View {
        Image(systemName: routine.symbol)
            .font(.system(size: 21, weight: .medium))
            .foregroundStyle(Palette.routine(routine.colorKey))
            .frame(width: 48, height: 48)
            .background(Palette.routine(routine.colorKey).opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
            .foregroundStyle(.white).background(Palette.green, in: RoundedRectangle(cornerRadius: 18))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SaveErrorBanner: View {
    @Environment(HabitStore.self) private var store
    var body: some View {
        if let message = store.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("save.error")
        }
    }
}
