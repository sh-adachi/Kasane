import SwiftUI
import Charts

struct KasaneProgressView: View {
    @Environment(HabitStore.self) private var store
    @State private var period: ProgressPeriod = .week
    @State private var selectedRoutine: Routine?

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var todayKey: String { HabitCalendar.dayKey(today) }
    private var startDate: Date {
        switch period {
        case .week:
            return HabitCalendar.weekDays(containing: today).first ?? today
        case .month:
            return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: today)) ?? today
        case .all:
            let firstDay = (store.data.routines.map(\.createdDay) + store.data.records.map(\.day)).min()
            return firstDay.map { HabitCalendar.date($0) } ?? today
        }
    }
    private var startKey: String { HabitCalendar.dayKey(startDate) }
    private var summary: HabitSummary {
        HabitAnalytics.summary(data: store.data, from: startKey, through: todayKey)
    }
    private var chartDays: [String] {
        let lowerBound = Calendar.current.date(byAdding: .day, value: -29, to: today) ?? today
        let beginning = max(startDate, lowerBound)
        let count = max(0, Calendar.current.dateComponents([.day], from: beginning, to: today).day ?? 0)
        return (0...count).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: beginning).map { HabitCalendar.dayKey($0) }
        }
    }
    private var chartPoints: [ProgressChartPoint] {
        let days = chartDays
        let seconds = HabitAnalytics.dailySeconds(data: store.data, days: days)
        return zip(days, seconds).map { ProgressChartPoint(day: $0.0, seconds: $0.1) }
    }
    private var routines: [Routine] {
        store.data.routines.sorted {
            let left = HabitAnalytics.summary(data: store.data, from: startKey, through: todayKey, routineID: $0.id).seconds
            let right = HabitAnalytics.summary(data: store.data, from: startKey, through: todayKey, routineID: $1.id).seconds
            return left == right ? $0.title < $1.title : left > right
        }
    }
    private var goalRoutines: [Routine] {
        store.data.routines.filter { $0.archivedDay == nil && ($0.weeklyGoalMinutes ?? 0) > 0 }
            .sorted { $0.title < $1.title }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("積み重ね")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                        Text("小さな一歩が、ちゃんと残っている。")
                            .font(.subheadline)
                            .foregroundStyle(Palette.muted)
                    }
                    .padding(.top, 14)

                    Picker("表示する期間", selection: $period) {
                        ForEach(ProgressPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("progress.period")

                    totalTimeCard

                    if store.data.routines.isEmpty && store.data.records.isEmpty {
                        emptyState
                    } else {
                        weeklyGoals
                        dailyChart
                        evaluationCard
                        routineBreakdown
                    }
                    Text("実施時間は「できなかった」の記録も含みます。\n達成率は今日までの予定から計算しています。")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 22)
            }
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedRoutine) { routine in
                RoutineProgressDetail(routine: routine, from: startKey, through: todayKey, periodTitle: period.title)
            }
        }
    }

    private var totalTimeCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(period.heroTitle)
                        .font(.subheadline.weight(.medium))
                    Text(DurationText.short(summary.seconds))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .accessibilityIdentifier("progress.totalTime")
                }
                Spacer(minLength: 4)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 29))
                    .rotationEffect(.degrees(-15))
                    .padding(13)
                    .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityHidden(true)
            }
            Rectangle()
                .fill(Palette.green.opacity(0.13))
                .frame(height: 1)
            HStack {
                Label("\(summary.done) 回できた", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(summary.seconds == 0 ? "ここから、少しずつ。" : "自分のために使った時間")
                    .font(.caption)
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(24)
        .background(Palette.mint, in: RoundedRectangle(cornerRadius: 28))
    }

    private var emptyState: some View {
        VStack(spacing: 15) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Palette.green)
                .padding(18)
                .background(Palette.mint.opacity(0.7), in: Circle())
            Text("最初の一歩を、残そう")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text("「ルーティン」で習慣を作って、\n「今日」から実施時間を記録すると、\nここに日々の積み重ねが育っていきます。")
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .cardStyle()
        .accessibilityIdentifier("progress.empty")
    }

    private var dailyChart: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("日々の実施時間")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(period == .all ? "直近30日まで" : rangeLabel)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }

            Chart(chartPoints) { point in
                BarMark(
                    x: .value("日付", point.label),
                    y: .value("分", Double(point.seconds) / 60)
                )
                .foregroundStyle(point.day == todayKey ? Palette.green : Palette.mint)
                .cornerRadius(5)
                .accessibilityLabel(point.accessibilityDate)
                .accessibilityValue(DurationText.short(point.seconds))
            }
            .chartYScale(domain: 0...max(30, Double(chartPoints.map(\.seconds).max() ?? 0) / 60 * 1.15))
            .chartXAxis {
                AxisMarks(values: axisLabels) { _ in
                    AxisValueLabel()
                        .foregroundStyle(Palette.muted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(Palette.muted.opacity(0.14))
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            Text("\(Int(minutes))分")
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
            .frame(height: 170)
            .accessibilityIdentifier("progress.dailyChart")

            if chartPoints.allSatisfy({ $0.seconds == 0 }) {
                Text("この期間の時間記録はまだありません。")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
        .cardStyle()
    }

    private var weeklyGoals: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "今週の目標", subtitle: "月曜日から今日までの実施時間")
            if goalRoutines.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("無理のない目安を、週ごとに。", systemImage: "flag")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text("ルーティンの編集で週間目標を設定すると、今週の進み具合を確認できます。")
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle()
            } else {
                ForEach(goalRoutines) { routine in
                    WeeklyGoalProgress(routine: routine).cardStyle()
                }
            }
        }
    }

    private var axisLabels: [String] {
        let points = chartPoints
        guard points.count > 7 else { return points.map(\.label) }
        let step = max(1, (points.count - 1) / 5)
        return points.enumerated().filter { $0.offset % step == 0 || $0.offset == points.count - 1 }.map(\.element.label)
    }

    private var rangeLabel: String {
        "\(ProgressChartPoint(day: startKey, seconds: 0).label) – \(ProgressChartPoint(day: todayKey, seconds: 0).label)"
    }

    private var evaluationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日までの達成率")
                    .font(.headline)
                Spacer()
                Text(summary.done + summary.missed + summary.pending == 0 ? "—" : "\(Int((summary.completionRate * 100).rounded()))%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("progress.completionRate")
            }
            GeometryReader { geometry in
                let total = max(1, summary.done + summary.missed + summary.pending)
                HStack(spacing: 0) {
                    Rectangle().fill(Palette.green)
                        .frame(width: geometry.size.width * CGFloat(summary.done) / CGFloat(total))
                    Rectangle().fill(Palette.orange.opacity(0.8))
                        .frame(width: geometry.size.width * CGFloat(summary.missed) / CGFloat(total))
                    Rectangle().fill(Palette.muted.opacity(0.13))
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            HStack(spacing: 12) {
                evaluationCount("できた", count: summary.done, color: Palette.green)
                Spacer(minLength: 0)
                evaluationCount("できなかった", count: summary.missed, color: Palette.orange)
                Spacer(minLength: 0)
                evaluationCount("未記録", count: summary.pending, color: Palette.muted.opacity(0.45))
            }
        }
        .foregroundStyle(Palette.ink)
        .cardStyle()
    }

    private func evaluationCount(_ label: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            Text("\(count)回")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
        }
        .accessibilityElement(children: .combine)
    }

    private var routineBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "習慣ごとの積み重ね", subtitle: "タップして記録をふり返る")
            ForEach(routines) { routine in
                let itemSummary = HabitAnalytics.summary(data: store.data, from: startKey, through: todayKey, routineID: routine.id)
                let streak = HabitAnalytics.streak(data: store.data, routineID: routine.id, through: todayKey)
                Button {
                    selectedRoutine = routine
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: routine.symbol)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Palette.routine(routine.colorKey))
                            .frame(width: 48, height: 48)
                            .background(Palette.routine(routine.colorKey).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(routine.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(2)
                            Text("\(itemSummary.done)回できた")
                                .font(.caption)
                                .foregroundStyle(Palette.muted)
                            if streak.current > 0 {
                                Label("連続\(streak.current)回", systemImage: "flame")
                                    .font(.caption2).foregroundStyle(Palette.orange)
                            }
                        }
                        Spacer(minLength: 5)
                        Text(DurationText.short(itemSummary.seconds))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.muted.opacity(0.6))
                    }
                    .cardStyle()
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("progress.routine.\(routine.id.uuidString)")
            }
        }
    }
}

private enum ProgressPeriod: String, CaseIterable, Identifiable {
    case week, month, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: "今週"
        case .month: "今月"
        case .all: "全期間"
        }
    }
    var heroTitle: String {
        switch self {
        case .week: "今週、積み重ねた時間"
        case .month: "今月、積み重ねた時間"
        case .all: "これまで積み重ねた時間"
        }
    }
}

private struct ProgressChartPoint: Identifiable {
    let day: String
    let seconds: Int
    var id: String { day }
    var label: String {
        let components = day.split(separator: "-")
        guard components.count == 3 else { return day }
        return "\(Int(components[1]) ?? 0)/\(Int(components[2]) ?? 0)"
    }
    var accessibilityDate: String {
        HabitCalendar.date(day).formatted(.dateTime.month().day().locale(Locale(identifier: "ja_JP")))
    }
}

private struct RoutineProgressDetail: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let routine: Routine
    let from: String
    let through: String
    let periodTitle: String

    private var records: [DailyRecord] {
        store.data.records.filter { $0.routineID == routine.id && $0.day >= from && $0.day <= through }
            .sorted { $0.day > $1.day }
    }
    private var summary: HabitSummary {
        HabitAnalytics.summary(data: store.data, from: from, through: through, routineID: routine.id)
    }
    private var streak: HabitStreak {
        HabitAnalytics.streak(data: store.data, routineID: routine.id, through: HabitCalendar.dayKey(Date()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 15) {
                        Image(systemName: routine.symbol)
                            .font(.system(size: 28))
                            .foregroundStyle(Palette.routine(routine.colorKey))
                            .frame(width: 62, height: 62)
                            .background(Palette.routine(routine.colorKey).opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(routine.title).font(.title2.bold()).foregroundStyle(Palette.ink)
                            Text("\(periodTitle)の記録").font(.subheadline).foregroundStyle(Palette.muted)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(DurationText.short(summary.seconds))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                        Text("できた \(summary.done)回  ·  できなかった \(summary.missed)回  ·  未記録 \(summary.pending)回")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .background(Palette.mint, in: RoundedRectangle(cornerRadius: 24))
                    VStack(alignment: .leading, spacing: 14) {
                        Label("これまでの連続達成", systemImage: "flame")
                            .font(.headline).foregroundStyle(Palette.ink)
                        HStack(alignment: .firstTextBaseline, spacing: 18) {
                            Text("連続\(streak.current)回")
                                .font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(Palette.orange)
                            Text("最長\(streak.best)回")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(Palette.muted)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("progress.streak.\(routine.title)")
                        Text("予定のある日の達成を数えます。休みの日は連続を保ちます。")
                            .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                    }.frame(maxWidth: .infinity, alignment: .leading).cardStyle()
                    if (routine.weeklyGoalMinutes ?? 0) > 0 && routine.archivedDay == nil {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("今週の目標").font(.headline).foregroundStyle(Palette.ink)
                            WeeklyGoalProgress(routine: routine)
                        }.cardStyle()
                    }
                    SectionHeading(title: "日々の記録", subtitle: "実施時間と、できたこと")
                    if records.isEmpty {
                        Text("この期間の記録はまだありません。\n「今日」で習慣を評価すると表示されます。")
                            .font(.subheadline)
                            .foregroundStyle(Palette.muted)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle()
                    } else {
                        ForEach(records) { record in
                            recordRow(record)
                        }
                    }
                }
                .padding(22)
            }
            .background(Palette.background)
            .navigationTitle("習慣のふり返り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Palette.green)
                }
            }
        }
        .accessibilityIdentifier("progress.detail")
    }

    private func recordRow(_ record: DailyRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: record.outcome == .done ? "checkmark.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(record.outcome == .done ? Palette.green : Palette.orange)
                VStack(alignment: .leading, spacing: 5) {
                    Text(HabitCalendar.date(record.day).formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ja_JP"))))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text(record.outcome == .done ? "できた" : "できなかった")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Text(DurationText.short(record.seconds))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
            }
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .lineSpacing(4)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

private struct WeeklyGoalProgress: View {
    @Environment(HabitStore.self) private var store
    let routine: Routine

    private var goalSeconds: Int { max(1, routine.weeklyGoalMinutes ?? 1) * 60 }
    private var seconds: Int {
        let today = Date()
        let monday = HabitCalendar.weekDays(containing: today).first ?? today
        return HabitAnalytics.summary(data: store.data, from: HabitCalendar.dayKey(monday),
                                      through: HabitCalendar.dayKey(today), routineID: routine.id).seconds
    }
    private var achieved: Bool { seconds >= goalSeconds }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Image(systemName: routine.symbol)
                    .foregroundStyle(Palette.routine(routine.colorKey))
                Text(routine.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                if achieved {
                    Label("達成", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Palette.green)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(DurationText.short(seconds))
                    .font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                Text("/ \(DurationText.short(goalSeconds))")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            GeometryReader { geometry in
                Capsule().fill(Palette.mint)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Palette.green)
                            .frame(width: geometry.size.width * min(1, Double(seconds) / Double(goalSeconds)))
                    }
            }.frame(height: 7)
            Text(achieved ? (seconds > goalSeconds ? "目標から\(DurationText.short(seconds - goalSeconds))、さらに積み重ねました。" : "今週の目標に届きました。") : "目標まであと\(DurationText.short(goalSeconds - seconds))")
                .font(.caption).foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("progress.weeklyGoal.\(routine.title)")
    }
}
