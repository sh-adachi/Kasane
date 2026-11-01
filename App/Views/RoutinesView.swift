import SwiftUI
import UIKit

struct KasaneRoutinesView: View {
    @Environment(HabitStore.self) private var store
    @State private var selectedWeekday = ((Calendar.current.component(.weekday, from: Date()) + 5) % 7) + 1
    @State private var scope: RoutineScope = .weekday
    @State private var editor: RoutineEditorRequest?
    @State private var routineToArchive: Routine?

    private let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
    private var today: String { HabitCalendar.dayKey(Date()) }
    private var activeRoutines: [Routine] { store.data.routines.filter { $0.archivedDay == nil } }
    private var archivedRoutines: [Routine] { store.data.routines.filter { $0.archivedDay != nil } }
    private var visibleRoutines: [Routine] {
        switch scope {
        case .weekday: return activeRoutines.filter { $0.weekdays(on: today).contains(selectedWeekday) }
        case .all: return activeRoutines
        case .archived: return archivedRoutines
        }
    }
    private var listTitle: String {
        switch scope {
        case .weekday: return "\(weekdays[selectedWeekday - 1])曜日のルーティン"
        case .all: return "続けているルーティン"
        case .archived: return "お休みしているルーティン"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                intro
                Picker("表示するルーティン", selection: $scope) {
                    ForEach(RoutineScope.allCases) { item in Text(item.rawValue).tag(item) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("routine.scope")

                if scope == .weekday { weekdaySelector }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeading(title: listTitle)
                        Spacer()
                        Text("\(visibleRoutines.count)件")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.muted)
                    }
                    if visibleRoutines.isEmpty {
                        emptyState
                    } else {
                        ForEach(visibleRoutines) { routine in
                            routineCard(routine)
                        }
                    }
                }
                if !activeRoutines.isEmpty && scope != .archived {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "leaf")
                            .foregroundStyle(Palette.green)
                        Text("小さく始めて、自分のペースで。曜日や目安の時間は、いつでも変更できます。")
                            .font(.footnote)
                            .foregroundStyle(Palette.muted)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .background(Palette.background)
        .navigationTitle("ルーティン")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = RoutineEditorRequest(routine: nil) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 36, height: 36)
                        .background(Palette.mint, in: Circle())
                }
                .accessibilityLabel("ルーティンを追加")
                .accessibilityIdentifier("routine.add")
            }
        }
        .sheet(item: $editor) { request in
            RoutineEditorView(routine: request.routine)
        }
        .confirmationDialog(
            "「\(routineToArchive?.title ?? "")」を休止しますか？",
            isPresented: Binding(get: { routineToArchive != nil }, set: { if !$0 { routineToArchive = nil } }),
            titleVisibility: .visible
        ) {
            Button("ルーティンを休止", role: .destructive) {
                if let routine = routineToArchive { _ = store.archiveRoutine(routine) }
                routineToArchive = nil
            }
            Button("キャンセル", role: .cancel) { routineToArchive = nil }
        } message: {
            Text("これまでの記録と積み重ねは残ります。「休止中」から再開できます。")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("暮らしに、続けるリズムを。")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Text("月曜日から日曜日まで、あなたの習慣を。")
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
        }
    }

    private var weekdaySelector: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let selected = selectedWeekday == day
                let count = activeRoutines.filter { $0.weekdays(on: today).contains(day) }.count
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedWeekday = day }
                } label: {
                    VStack(spacing: 11) {
                        Text(weekdays[day - 1])
                            .font(.subheadline.weight(.semibold))
                        Text("\(count)")
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(selected ? Color.white.opacity(0.8) : Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 75)
                    .foregroundStyle(selected ? Color.white : Palette.ink)
                    .background(selected ? Palette.ink : Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(weekdays[day - 1])曜日、\(count)件")
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("routine.filter.weekday.\(day)")
            }
        }
    }

    private func routineCard(_ routine: Routine) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                editor = RoutineEditorRequest(routine: routine)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: routine.symbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Palette.routine(routine.colorKey))
                        .frame(width: 51, height: 56)
                        .background(Palette.routine(routine.colorKey).opacity(0.10), in: RoundedRectangle(cornerRadius: 17))
                    VStack(alignment: .leading, spacing: 7) {
                        Text(routine.title)
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(routine.targetMinutes)分")
                            if !routine.preferredTime.isEmpty {
                                Text("·")
                                Text(routine.preferredTime)
                                if routine.reminderEnabled == true {
                                    Image(systemName: routine.archivedDay == nil ? "bell.fill" : "bell.slash")
                                        .font(.caption2)
                                        .accessibilityLabel(routine.archivedDay == nil ? "通知を設定済み" : "通知は休止中")
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        if let weeklyGoal = routine.weeklyGoalMinutes {
                            Label("週の目標 \(DurationText.short(weeklyGoal * 60))", systemImage: "target")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Palette.routine(routine.colorKey))
                        }
                        if scope != .weekday {
                            Text(weekdayDescription(displayWeekdays(for: routine)))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Palette.routine(routine.colorKey))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(routine.title)、目安\(routine.targetMinutes)分、編集")
            .accessibilityValue(cardAccessibilityDetails(routine))
            .accessibilityIdentifier("routine.edit.\(routine.id.uuidString)")
            Menu {
                Button("編集", systemImage: "pencil") { editor = RoutineEditorRequest(routine: routine) }
                if routine.archivedDay != nil {
                    Button("ルーティンを再開", systemImage: "play") { _ = store.restoreRoutine(routine) }
                } else {
                    Button("休止する", systemImage: "pause", role: .destructive) { routineToArchive = routine }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(routine.title)の操作")
        }
        .cardStyle()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: scope == .archived ? "pause.circle" : "leaf")
                .font(.system(size: 33, weight: .light))
                .foregroundStyle(Palette.green)
                .frame(width: 76, height: 76)
                .background(Palette.mint.opacity(0.6), in: Circle())
            Text(emptyTitle)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            if scope != .archived {
                Button { editor = RoutineEditorRequest(routine: nil) } label: {
                    Label("ルーティンをつくる", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)
                        .foregroundStyle(.white)
                        .background(Palette.ink, in: Capsule())
                }
                .padding(.top, 5)
                .accessibilityIdentifier("routine.empty.add")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 3)
        .padding(.vertical, 12)
        .cardStyle()
    }

    private var emptyTitle: String {
        if scope == .archived { return "休止中のルーティンはありません" }
        return activeRoutines.isEmpty ? "最初のひとつを、ここから。" : "この曜日は、余白の日。"
    }
    private var emptyMessage: String {
        if scope == .archived { return "少しお休みしたい習慣は、\n記録を残したまま休止できます。" }
        return activeRoutines.isEmpty ? "読書を10分、ストレッチを5分。\n続けたいことから始めましょう。" : "新しく習慣を追加するか、\nほかの曜日のルーティンを見てみましょう。"
    }

    private func cardAccessibilityDetails(_ routine: Routine) -> String {
        var details: [String] = []
        if let goal = routine.weeklyGoalMinutes { details.append("週の目標\(goal)分") }
        if !routine.preferredTime.isEmpty { details.append("予定\(routine.preferredTime)") }
        if routine.reminderEnabled == true && !routine.preferredTime.isEmpty {
            details.append(routine.archivedDay == nil ? "通知を設定済み" : "通知は休止中")
        }
        return details.joined(separator: "、")
    }

    private func displayWeekdays(for routine: Routine) -> [Int] {
        if routine.archivedDay != nil {
            return routine.pausedWeekdays
                ?? routine.schedules.sorted { $0.effectiveDay < $1.effectiveDay }.last(where: { !$0.weekdays.isEmpty })?.weekdays
                ?? []
        }
        return routine.weekdays(on: today)
    }

    private func weekdayDescription(_ values: [Int]) -> String {
        if Set(values) == Set(1...7) { return "毎日" }
        if Set(values) == Set(1...5) { return "平日" }
        return values.sorted().filter { (1...7).contains($0) }.map { weekdays[$0 - 1] }.joined(separator: "・")
    }
}

private enum RoutineScope: String, CaseIterable, Identifiable {
    case weekday = "曜日別"
    case all = "すべて"
    case archived = "休止中"
    var id: String { rawValue }
}

private struct RoutineEditorRequest: Identifiable {
    let id = UUID()
    let routine: Routine?
}

struct RoutineEditorView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private let routine: Routine?
    @State private var title: String
    @State private var symbol: String
    @State private var colorKey: String
    @State private var selectedWeekdays: Set<Int>
    @State private var targetMinutes: Int
    @State private var hasPreferredTime: Bool
    @State private var preferredTime: Date
    @State private var weeklyGoalEnabled: Bool
    @State private var weeklyGoalMinutesText: String
    @State private var reminderEnabled: Bool
    @FocusState private var titleFocused: Bool
    @FocusState private var weeklyGoalFocused: Bool

    private let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
    private let symbols: [(String, String)] = [
        ("book.closed", "読書"), ("figure.flexibility", "ストレッチ"),
        ("character.bubble", "語学"), ("figure.walk", "ウォーキング"),
        ("drop", "水分補給"), ("sparkles", "その他")
    ]
    private let colors: [(String, String)] = [("green", "グリーン"), ("blue", "ブルー"), ("orange", "オレンジ"), ("purple", "パープル")]

    init(routine: Routine? = nil) {
        self.routine = routine
        let today = HabitCalendar.dayKey(Date())
        _title = State(initialValue: routine?.title ?? "")
        _symbol = State(initialValue: routine?.symbol ?? "book.closed")
        _colorKey = State(initialValue: routine?.colorKey ?? "green")
        let initialWeekdays = routine?.archivedDay != nil
            ? routine?.pausedWeekdays ?? routine?.schedules.sorted { $0.effectiveDay < $1.effectiveDay }.last(where: { !$0.weekdays.isEmpty })?.weekdays ?? Array(1...7)
            : routine?.weekdays(on: today) ?? Array(1...7)
        _selectedWeekdays = State(initialValue: Set(initialWeekdays))
        _targetMinutes = State(initialValue: routine?.targetMinutes ?? 15)
        _hasPreferredTime = State(initialValue: !(routine?.preferredTime.isEmpty ?? true))
        let parts = (routine?.preferredTime ?? "20:00").split(separator: ":").compactMap { Int($0) }
        let date = Calendar.current.date(bySettingHour: parts.first ?? 20, minute: parts.count > 1 ? parts[1] : 0, second: 0, of: Date()) ?? Date()
        _preferredTime = State(initialValue: date)
        _weeklyGoalEnabled = State(initialValue: routine?.weeklyGoalMinutes != nil)
        _weeklyGoalMinutesText = State(initialValue: String(routine?.weeklyGoalMinutes ?? 75))
        _reminderEnabled = State(initialValue: routine?.reminderEnabled ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    preview
                    SaveErrorBanner()
                    if routine == nil { templates }
                    nameSection
                    appearanceSection
                    scheduleSection
                        .disabled(routine?.archivedDay != nil)
                        .opacity(routine?.archivedDay != nil ? 0.65 : 1)
                    durationSection
                    weeklyGoalSection
                    timeSection
                    Text(routine == nil ? "がんばりすぎない、小さな目標がおすすめです。" : routine?.archivedDay != nil ? "曜日の変更は、ルーティンを再開してから行えます。" : "曜日の変更は今日から適用されます。過去の記録はそのまま残ります。")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .lineSpacing(4)
                }
                .padding(22)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .navigationTitle(routine == nil ? "ルーティンをつくる" : "ルーティンを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Palette.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                        .accessibilityIdentifier("routine.save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        titleFocused = false
                        weeklyGoalFocused = false
                    }
                }
            }
            .tint(Palette.green)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var preview: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Palette.routine(colorKey))
                .frame(width: 68, height: 68)
                .background(Palette.routine(colorKey).opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
            VStack(alignment: .leading, spacing: 6) {
                Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "小さな習慣を、ひとつ。" : title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Text("1回 \(targetMinutes)分から積み重ねる")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var templates: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("たとえば、こんな習慣")
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.muted)
            HStack(spacing: 8) {
                templateButton("読書", symbol: "book.closed", minutes: 15, color: "green")
                templateButton("ストレッチ", symbol: "figure.flexibility", minutes: 5, color: "orange")
                templateButton("英語", symbol: "character.bubble", minutes: 20, color: "blue")
            }
        }
    }

    private func templateButton(_ name: String, symbol value: String, minutes: Int, color: String) -> some View {
        Button {
            title = name
            symbol = value
            targetMinutes = minutes
            colorKey = color
            titleFocused = false
        } label: {
            HStack(spacing: 5) {
                Image(systemName: value)
                Text(name)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(Palette.ink)
            .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("routine.template.\(name)")
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionHeading(title: "続けたいこと")
            TextField("例：寝る前に読書", text: $title)
                .font(.body)
                .cardStyle()
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit { titleFocused = false }
                .accessibilityIdentifier("routine.title")
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(title: "アイコンとカラー")
            HStack(spacing: 8) {
                ForEach(symbols, id: \.0) { item in
                    Button { symbol = item.0 } label: {
                        Image(systemName: item.0)
                            .font(.system(size: 21, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(symbol == item.0 ? Palette.routine(colorKey) : Palette.muted)
                            .background(symbol == item.0 ? Palette.routine(colorKey).opacity(0.13) : .white, in: RoundedRectangle(cornerRadius: 13))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13)
                                    .strokeBorder(symbol == item.0 ? Palette.routine(colorKey).opacity(0.65) : .clear, lineWidth: 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.1)のアイコン")
                    .accessibilityAddTraits(symbol == item.0 ? .isSelected : [])
                }
            }
            HStack(spacing: 17) {
                ForEach(colors, id: \.0) { item in
                    Button { colorKey = item.0 } label: {
                        Circle()
                            .fill(Palette.routine(item.0))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if colorKey == item.0 {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(5)
                            .overlay {
                                Circle().strokeBorder(colorKey == item.0 ? Palette.routine(item.0).opacity(0.45) : .clear, lineWidth: 1.5)
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.1)
                    .accessibilityAddTraits(colorKey == item.0 ? .isSelected : [])
                }
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(title: "取り組む曜日", subtitle: "週に何日でも。自分に合うリズムで。")
            HStack(spacing: 7) {
                ForEach(1...7, id: \.self) { day in
                    let selected = selectedWeekdays.contains(day)
                    Button {
                        if selected { selectedWeekdays.remove(day) } else { selectedWeekdays.insert(day) }
                    } label: {
                        Text(weekdays[day - 1])
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(selected ? .white : Palette.muted)
                            .background(selected ? Palette.ink : .white, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(weekdays[day - 1])曜日")
                    .accessibilityValue(selected ? "選択中" : "未選択")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("routine.weekday.\(day)")
                }
            }
            HStack(spacing: 16) {
                weekdayPreset("毎日", values: Set(1...7))
                weekdayPreset("平日", values: Set(1...5))
                weekdayPreset("週末", values: [6, 7])
                Spacer()
                if selectedWeekdays.isEmpty {
                    Text("1日以上選択してください")
                        .font(.caption2)
                        .foregroundStyle(Palette.orange)
                }
            }
        }
    }

    private func weekdayPreset(_ title: String, values: Set<Int>) -> some View {
        Button(title) { selectedWeekdays = values }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.green)
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "1回の目安", subtitle: "実際に取り組んだ時間は、あとで記録できます。")
            HStack {
                Text("目安の時間")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Stepper(value: $targetMinutes, in: 1...720) {
                    Text("\(targetMinutes) 分")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .fixedSize()
                .accessibilityIdentifier("routine.targetMinutes")
            }
            .cardStyle()
            HStack(spacing: 8) {
                ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                    Button { targetMinutes = minutes } label: {
                        Text("\(minutes)分")
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .foregroundStyle(targetMinutes == minutes ? Palette.green : Palette.muted)
                            .background(targetMinutes == minutes ? Palette.mint : .white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weeklyGoalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "1週間の時間目標", subtitle: "月曜日から日曜日までの積み重ねに、目標を。")
            VStack(alignment: .leading, spacing: 16) {
                Toggle("週間目標を決める", isOn: $weeklyGoalEnabled)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.green)
                    .accessibilityIdentifier("routine.weeklyGoalEnabled")
                if weeklyGoalEnabled {
                    Divider()
                    HStack {
                        Text("1週間の目標")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 12)
                        TextField("75", text: $weeklyGoalMinutesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Palette.ink)
                            .frame(width: 90)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 11)
                            .background(Palette.background, in: RoundedRectangle(cornerRadius: 10))
                            .focused($weeklyGoalFocused)
                            .accessibilityLabel("週間目標の分数")
                            .accessibilityIdentifier("routine.weeklyGoalMinutes")
                        Text("分")
                            .font(.subheadline)
                            .foregroundStyle(Palette.muted)
                    }
                    HStack(spacing: 8) {
                        ForEach([15, 30, 60, 120], id: \.self) { minutes in
                            Button {
                                weeklyGoalMinutesText = String(minutes)
                                weeklyGoalFocused = false
                            } label: {
                                Text("\(minutes)分")
                                    .font(.caption.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .foregroundStyle(weeklyGoalMinutes == minutes ? Palette.green : Palette.muted)
                                    .background(weeklyGoalMinutes == minutes ? Palette.mint : Palette.background, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !isWeeklyGoalValid {
                        Text("1〜10,080分の整数を入力してください。")
                            .font(.caption)
                            .foregroundStyle(Palette.orange)
                            .accessibilityIdentifier("routine.weeklyGoalError")
                    }
                }
            }
            .cardStyle()
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "取り組む時刻", subtitle: "選んだ曜日の決まった時刻に、習慣を思い出すきっかけを。")
            VStack(spacing: 14) {
                Toggle("時刻を決める", isOn: $hasPreferredTime)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.green)
                    .accessibilityIdentifier("routine.hasPreferredTime")
                if hasPreferredTime {
                    Divider()
                    DatePicker("開始の目安", selection: $preferredTime, displayedComponents: .hourAndMinute)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .accessibilityIdentifier("routine.preferredTime")
                    Divider()
                    Toggle("通知でお知らせ", isOn: Binding(
                        get: { reminderEnabled },
                        set: { enabled in
                            reminderEnabled = enabled
                            if enabled {
                                Task { await store.requestReminderPermission() }
                            }
                        }
                    ))
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.green)
                    .accessibilityIdentifier("routine.reminderEnabled")
                    if reminderEnabled {
                        reminderDetails
                    }
                }
            }
            .cardStyle()
        }
    }

    private var reminderDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            if routine?.archivedDay != nil {
                Label("休止中は通知が届きません。再開すると通知も再開します。", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
            if !store.reminderStatusMessage.isEmpty {
                Text(store.reminderStatusMessage)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("routine.reminderStatus")
            }
            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            } label: {
                Label("通知設定を開く", systemImage: "arrow.up.forward.app")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.green)
            }
            .accessibilityIdentifier("routine.reminderSettings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weeklyGoalMinutes: Int? {
        let text = weeklyGoalMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        return Int(text)
    }

    private var isWeeklyGoalValid: Bool {
        guard weeklyGoalEnabled else { return true }
        guard let minutes = weeklyGoalMinutes else { return false }
        return (1...10_080).contains(minutes)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedWeekdays.isEmpty && (1...720).contains(targetMinutes) && isWeeklyGoalValid
    }

    private func save() {
        guard isValid else { return }
        let day = HabitCalendar.dayKey(Date())
        let values = selectedWeekdays.sorted()
        let time: String
        if hasPreferredTime {
            let components = Calendar.current.dateComponents([.hour, .minute], from: preferredTime)
            time = String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
        } else {
            time = ""
        }
        var schedules = routine?.schedules ?? []
        if routine == nil || (routine?.archivedDay == nil && routine?.weekdays(on: day).sorted() != values) {
            schedules.removeAll { $0.effectiveDay == day }
            schedules.append(ScheduleRevision(effectiveDay: day, weekdays: values))
        }
        var value = Routine(
            id: routine?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            symbol: symbol,
            colorKey: colorKey,
            targetMinutes: targetMinutes,
            preferredTime: time,
            createdDay: routine?.createdDay ?? day,
            archivedDay: routine?.archivedDay,
            schedules: schedules
        )
        value.pausedWeekdays = routine?.pausedWeekdays
        value.weeklyGoalMinutes = weeklyGoalEnabled ? weeklyGoalMinutes : nil
        value.reminderEnabled = hasPreferredTime && reminderEnabled
        if store.saveRoutine(value) { dismiss() }
    }
}
