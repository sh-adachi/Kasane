import SwiftUI

private struct RecordSelection: Identifiable {
    let id = UUID()
    let routine: Routine
    let day: String
}

struct TodayView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var lastActiveDay = HabitCalendar.dayKey(Date())
    @State private var editing: RecordSelection?
    @State private var adding = false
    @State private var showCalendar = false
    @State private var showInfo = false
    @State private var showDataSettings = false
    private var day: String { HabitCalendar.dayKey(selectedDate) }
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    private var isFuture: Bool { day > HabitCalendar.dayKey(Date()) }
    private var summary: HabitSummary { HabitAnalytics.summary(data: store.data, from: day, through: day) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    weekStrip
                    if store.readOnly {
                        Label("記録を読み込めませんでした。保存を停止しています。", systemImage: "exclamationmark.triangle")
                            .font(.subheadline).foregroundStyle(.red).cardStyle()
                    }
                    if store.isDemo {
                        Label("体験用データ · 実際の記録とは別です", systemImage: "sparkles")
                            .font(.caption).foregroundStyle(Palette.orange)
                    }
                    if store.data.routines.isEmpty { welcome }
                    else {
                        dailySummary
                        if let timer = store.data.timer, let routine = store.data.routines.first(where: { $0.id == timer.routineID }) {
                            Button { store.showTimer = true } label: {
                                HStack {
                                    Image(systemName: "waveform.path").symbolEffect(.variableColor)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(routine.title)を計測中").font(.subheadline.bold())
                                        TimelineView(.periodic(from: .now, by: 1)) { context in
                                            Text(DurationText.clock(timer.elapsed(at: context.date))).font(.caption.monospacedDigit())
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }.foregroundStyle(Palette.green).padding(18).background(Palette.mint, in: RoundedRectangle(cornerRadius: 20))
                            }.accessibilityIdentifier("timer.resume")
                        }
                        routineList
                    }
                    Text("小さな一歩も、ちゃんと積み重なっている。")
                        .font(.caption).foregroundStyle(Palette.muted).frame(maxWidth: .infinity).padding(.vertical, 8)
                }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 24)
            }
            .background(Palette.background)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    if day == lastActiveDay { selectedDate = Calendar.current.startOfDay(for: Date()) }
                    lastActiveDay = HabitCalendar.dayKey(Date())
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 7) {
                        Image(systemName: "circle.hexagongrid.fill").font(.title3).foregroundStyle(Palette.green)
                        Text("かさね").font(.system(.headline, design: .rounded)).tracking(3)
                    }.foregroundStyle(Palette.ink).fixedSize()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDataSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("データと設定").accessibilityIdentifier("today.settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showInfo = true } label: { Image(systemName: "info.circle") }.accessibilityLabel("アプリについて")
                }
            }
            .sheet(item: $editing) { selection in RecordEditorView(routine: selection.routine, day: selection.day) }
            .sheet(isPresented: $adding) { RoutineEditorView() }
            .sheet(isPresented: $showInfo) { AboutView() }
            .sheet(isPresented: $showDataSettings) { DataManagementView() }
            .sheet(isPresented: $showCalendar) {
                NavigationStack {
                    DatePicker("記録する日", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical).environment(\.locale, Locale(identifier: "ja_JP"))
                        .padding().navigationTitle("日付を選ぶ").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { showCalendar = false } } }
                }.presentationDetents([.medium, .large])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Button { showCalendar = true } label: {
                    HStack(spacing: 7) {
                        Text(selectedDate.formatted(.dateTime.year().month().day()).uppercased()).font(.caption.weight(.semibold)).tracking(1)
                        Image(systemName: "chevron.down").font(.caption2)
                    }.foregroundStyle(Palette.muted)
                }.accessibilityIdentifier("today.date")
                Spacer()
                if !isToday { Button("今日へ") { selectedDate = Calendar.current.startOfDay(for: Date()) }.font(.caption.bold()) }
            }
            Text(isToday ? "今日も、ひとつずつ。" : selectedDate.formatted(.dateTime.month().day().weekday(.wide)))
                .font(.system(size: 29, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 4) {
            Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left").font(.caption.bold()).frame(width: 24, height: 60) }
                .accessibilityLabel("前の週")
            ForEach(HabitCalendar.weekDays(containing: selectedDate), id: \.self) { date in
                let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                let key = HabitCalendar.dayKey(date)
                let hasRecord = store.data.records.contains { $0.day == key }
                Button { selectedDate = date } label: {
                    VStack(spacing: 8) {
                        Text(["月", "火", "水", "木", "金", "土", "日"][HabitCalendar.weekday(key) - 1]).font(.caption2)
                        Text("\(Calendar.current.component(.day, from: date))").font(.system(.callout, design: .rounded, weight: .semibold))
                        Circle().fill(selected ? .white : hasRecord ? Palette.green : .clear).frame(width: 4, height: 4)
                    }.foregroundStyle(selected ? .white : Palette.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(selected ? Palette.green : .clear, in: RoundedRectangle(cornerRadius: 18))
                }.accessibilityLabel(date.formatted(.dateTime.month().day().weekday()))
            }
            Button { shiftWeek(1) } label: { Image(systemName: "chevron.right").font(.caption.bold()).frame(width: 24, height: 60) }
                .accessibilityLabel("次の週")
        }
    }

    private var dailySummary: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(isFuture ? "これからの予定" : "\(isToday ? "今日" : "この日")の積み重ね").font(.subheadline.weight(.semibold))
                Text(DurationText.short(summary.seconds)).font(.system(size: 32, weight: .bold, design: .rounded)).accessibilityIdentifier("today.totalTime")
                Text(isFuture ? "予定に合わせて、無理なく。" : summary.done > 0 ? "できた分だけ、前に進んだ。" : "まずは、ひとつから。")
                    .font(.caption).foregroundStyle(Palette.green.opacity(0.8))
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(Palette.green.opacity(0.10), lineWidth: 8)
                Circle().trim(from: 0, to: summary.completionRate).stroke(Palette.green, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(summary.done) / \(summary.done + summary.missed + summary.pending)").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("できた").font(.caption2)
                }
            }.frame(width: 84, height: 84).accessibilityElement(children: .combine)
        }.foregroundStyle(Palette.ink).padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.mint, in: RoundedRectangle(cornerRadius: 28))
    }

    private var routineList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeading(title: "\(isToday ? "今日" : "この日")のルーティン")
                Spacer()
                Button { adding = true } label: { Image(systemName: "plus").font(.headline).frame(width: 32, height: 32).background(.white, in: Circle()) }
                    .accessibilityLabel("ルーティンを追加").accessibilityIdentifier("today.add")
            }
            if store.routines(on: day).isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer").font(.largeTitle).foregroundStyle(Palette.green)
                    Text("この日は、ひと休み。").font(.headline)
                    Text("予定のある曜日を選ぶか、ルーティンを追加できます。").font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).cardStyle()
            }
            ForEach(store.routines(on: day)) { routine in
                let record = store.record(for: routine, day: day)
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        HabitIcon(routine: routine)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(routine.title).font(.headline).foregroundStyle(Palette.ink)
                            Text((routine.preferredTime.isEmpty ? "" : routine.preferredTime + " · ") + "目安 \(routine.targetMinutes)分")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 4)
                        if let record {
                            VStack(alignment: .trailing, spacing: 5) {
                                Label(record.outcome == .done ? "できた" : "できなかった", systemImage: record.outcome == .done ? "checkmark.circle.fill" : "minus.circle")
                                    .font(.caption.weight(.semibold)).foregroundStyle(record.outcome == .done ? Palette.green : Palette.muted)
                                Text(DurationText.short(record.seconds)).font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                    if !isFuture {
                        HStack(spacing: 12) {
                            if isToday {
                                Button { store.startTimer(for: routine) } label: {
                                    Label(record == nil ? "はじめる" : "追加で計測", systemImage: "play.fill").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .foregroundStyle(.white).background(Palette.green, in: RoundedRectangle(cornerRadius: 13))
                                }.accessibilityIdentifier("today.start.\(routine.title)")
                            }
                            Button { editing = RecordSelection(routine: routine, day: day) } label: {
                                Label(record == nil ? "結果を記録" : "記録を編集", systemImage: "square.and.pencil")
                                    .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .foregroundStyle(Palette.green).background(Palette.background, in: RoundedRectangle(cornerRadius: 13))
                            }.accessibilityIdentifier("today.record.\(routine.title)")
                        }
                    }
                }.cardStyle()
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(Palette.green.opacity(0.14)).frame(width: 110, height: 24).offset(x: 8, y: 28)
                RoundedRectangle(cornerRadius: 15).fill(Palette.green.opacity(0.32)).frame(width: 94, height: 24).offset(x: -4, y: 0)
                RoundedRectangle(cornerRadius: 15).fill(Palette.green).frame(width: 76, height: 24).offset(x: 5, y: -28)
            }.frame(height: 105).frame(maxWidth: .infinity)
            Text("小さな習慣を、\n大きな積み重ねに。").font(.system(size: 29, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
            Text("曜日を決めて、できた日も、\nできなかった日も記録。\n取り組んだ時間は、あなたの積み重ねに。")
                .font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(6)
            Button("最初のルーティンを作る") { adding = true }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("today.firstRoutine")
            Text("ログイン不要 · 記録はこの端末に保存").font(.caption).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
        }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 28))
    }

    private func shiftWeek(_ value: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: value * 7, to: selectedDate)!
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("かさね", systemImage: "circle.hexagongrid.fill").font(.title.bold()).foregroundStyle(Palette.green)
                    Text("小さな習慣を、大きな積み重ねに。")
                }
                Section("記録について") {
                    Text("「できた」「できなかった」と実施時間を記録します。途中まで取り組んだ時間も合計に含まれます。未記録は自動で「できなかった」にはなりません。")
                    Text("曜日の変更は当日以降に反映します。ルーティンを休止しても、それまでの記録は残ります。")
                    Text("タイマーはアプリを閉じても継続します。日をまたいだ時間は、開始した日にまとめて記録します。目安時間で自動停止はしません。")
                }
                Section("データの保存") {
                    Text("データはこの端末内に保存されます。アカウント、通信、クラウド同期はありません。アプリを削除すると記録も削除されます。")
                }
            }.navigationTitle("かさねについて").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}
