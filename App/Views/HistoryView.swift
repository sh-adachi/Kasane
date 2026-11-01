import SwiftUI

struct KasaneHistoryView: View {
    @Environment(HabitStore.self) private var store
    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var selectedRoutineID: UUID?
    @State private var editing: HistoryRecordSelection?

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.firstWeekday = 2
        return value
    }
    private var today: String { HabitCalendar.dayKey(Date()) }
    private var selectedDay: String { HabitCalendar.dayKey(selectedDate) }
    private var isFuture: Bool { selectedDay > today }
    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }
    private var monthEnd: Date {
        calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
    }
    private var monthDays: [Date?] {
        let offset = (calendar.component(.weekday, from: monthStart) + 5) % 7
        let count = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let dates = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: monthStart) }
        let remaining = (7 - (offset + count) % 7) % 7
        return Array(repeating: nil, count: offset) + dates + Array(repeating: nil, count: remaining)
    }
    private var monthSummary: HabitSummary {
        HabitAnalytics.summary(data: store.data, from: HabitCalendar.dayKey(monthStart),
                               through: min(HabitCalendar.dayKey(monthEnd), today), routineID: selectedRoutineID)
    }
    private var selectedRoutines: [Routine] {
        store.routines(on: selectedDay).filter { selectedRoutineID == nil || $0.id == selectedRoutineID }
    }
    private var filterTitle: String {
        store.data.routines.first { $0.id == selectedRoutineID }?.title ?? "すべての習慣"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("履歴")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                        Text("ふり返って、また一歩。")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }.padding(.top, 14)

                    HStack {
                        Menu {
                            Picker("習慣を絞り込む", selection: $selectedRoutineID) {
                                Text("すべての習慣").tag(nil as UUID?)
                                ForEach(store.data.routines) { routine in
                                    Text(routine.title).tag(Optional(routine.id))
                                }
                            }
                        } label: {
                            Label(filterTitle, systemImage: "line.3.horizontal.decrease")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(Palette.green)
                                .padding(.horizontal, 15).padding(.vertical, 11)
                                .background(.white, in: Capsule())
                        }
                        .accessibilityIdentifier("history.filter")
                        Spacer(minLength: 8)
                        Button("今日へ") {
                            displayedMonth = Date()
                            selectedDate = Date()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.green)
                        .accessibilityIdentifier("history.today")
                    }

                    calendarCard
                    monthTotals
                    selectedDayDetail
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { selection in
                RecordEditorView(routine: selection.routine, day: selection.day)
            }
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 20) {
            HStack {
                Button { moveMonth(-1) } label: {
                    Image(systemName: "chevron.left").font(.subheadline.bold()).frame(width: 38, height: 40)
                }
                .accessibilityLabel("前の月")
                .accessibilityIdentifier("history.previousMonth")
                Spacer()
                Text(monthStart.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "ja_JP"))))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("history.month")
                Spacer()
                Button { moveMonth(1) } label: {
                    Image(systemName: "chevron.right").font(.subheadline.bold()).frame(width: 38, height: 40)
                }
                .accessibilityLabel("次の月")
                .accessibilityIdentifier("history.nextMonth")
            }.foregroundStyle(Palette.green)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 7) {
                ForEach(["月", "火", "水", "木", "金", "土", "日"], id: \.self) { label in
                    Text(label).font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity).padding(.bottom, 5)
                }
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date { dayCell(date) }
                    else { Color.clear.frame(height: 49).accessibilityHidden(true) }
                }
            }

            HStack(spacing: 14) {
                legend("できた", symbol: "circle.fill", color: Palette.green)
                legend("できなかった", symbol: "circle.fill", color: Palette.orange)
                legend("未記録", symbol: "circle", color: Palette.muted)
            }
            Text("日付を選ぶと、その日の記録を編集できます。")
                .font(.caption).foregroundStyle(Palette.muted)
        }.cardStyle()
    }

    private func dayCell(_ date: Date) -> some View {
        let day = HabitCalendar.dayKey(date)
        let selected = day == selectedDay
        let future = day > today
        let result = HabitAnalytics.summary(data: store.data, from: day, through: day, routineID: selectedRoutineID)
        return Button { selectedDate = date } label: {
            VStack(spacing: 6) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(.subheadline, design: .rounded).weight(selected || day == today ? .bold : .regular))
                    .foregroundStyle(future ? Palette.muted.opacity(0.65) : Palette.ink)
                HStack(spacing: 3) {
                    if !future {
                        if result.done > 0 { Circle().fill(Palette.green).frame(width: 4, height: 4) }
                        if result.missed > 0 { Circle().fill(Palette.orange).frame(width: 4, height: 4) }
                        if result.pending > 0 { Circle().stroke(Palette.muted, lineWidth: 1).frame(width: 4, height: 4) }
                    }
                }.frame(height: 5)
            }
            .frame(maxWidth: .infinity).frame(height: 49)
            .background(selected ? Palette.mint : .clear, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? Palette.green : day == today ? Palette.green.opacity(0.35) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ja_JP"))))
        .accessibilityValue(future ? "今後の予定 \(result.pending)件" : "できた \(result.done)件、できなかった \(result.missed)件、未記録 \(result.pending)件")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("history.day.\(day)")
    }

    private func legend(_ label: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 6)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(Palette.muted)
        }
    }

    private var monthTotals: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Text("この月の積み重ね").font(.caption.weight(.medium)).foregroundStyle(Palette.green)
                Text(DurationText.short(monthSummary.seconds))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("history.totalTime")
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 7) {
                Text("\(monthSummary.done)回できた").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.green)
                Text("今日までの記録").font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .padding(22)
        .background(Palette.mint.opacity(0.7), in: RoundedRectangle(cornerRadius: 24))
    }

    private var selectedDayDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: selectedDate.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ja_JP"))),
                           subtitle: isFuture ? "これからの予定 · 未来の記録は編集できません" : "できた日も、できなかった日も。")
            if selectedRoutines.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("この日の予定・記録はありません", systemImage: "cup.and.saucer")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text("習慣を始める前や、休みの日はそのままで大丈夫。")
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle()
                    .accessibilityIdentifier("history.emptyDay")
            } else {
                ForEach(selectedRoutines) { routine in
                    routineRow(routine)
                }
            }
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        let record = store.record(for: routine, day: selectedDay)
        let label = record.map { $0.outcome == .done ? "できた" : "できなかった" } ?? (isFuture ? "予定" : "未記録")
        let symbol = record.map { $0.outcome == .done ? "checkmark.circle.fill" : "minus.circle.fill" } ?? "circle.dashed"
        let color = record.map { $0.outcome == .done ? Palette.green : Palette.orange } ?? Palette.muted
        return Button {
            editing = HistoryRecordSelection(routine: routine, day: selectedDay)
        } label: {
            HStack(spacing: 12) {
                HabitIcon(routine: routine)
                VStack(alignment: .leading, spacing: 6) {
                    Text(routine.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Label(label, systemImage: symbol).font(.caption).foregroundStyle(color)
                }
                Spacer(minLength: 5)
                VStack(alignment: .trailing, spacing: 7) {
                    Text(record.map { DurationText.short($0.seconds) } ?? "目安 \(routine.targetMinutes)分")
                        .font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                    if !isFuture {
                        Image(systemName: "square.and.pencil").font(.caption).foregroundStyle(Palette.muted)
                    }
                }
            }.cardStyle()
        }
        .buttonStyle(.plain)
        .disabled(isFuture || store.readOnly)
        .accessibilityIdentifier("history.record.\(routine.title)")
    }

    private func moveMonth(_ offset: Int) {
        guard let month = calendar.date(byAdding: .month, value: offset, to: monthStart) else { return }
        let dayNumber = min(calendar.component(.day, from: selectedDate), calendar.range(of: .day, in: .month, for: month)?.count ?? 28)
        displayedMonth = month
        selectedDate = calendar.date(byAdding: .day, value: dayNumber - 1, to: month) ?? month
    }
}

private struct HistoryRecordSelection: Identifiable {
    let id = UUID()
    let routine: Routine
    let day: String
}
