import SwiftUI

struct RecordEditorView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let routine: Routine
    let day: String
    @State private var outcome: Outcome = .done
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var note = ""
    @State private var confirmClear = false
    @FocusState private var focused: Bool
    private var valid: Bool {
        guard let m = Int(minutes.isEmpty ? "0" : minutes), let s = Int(seconds.isEmpty ? "0" : seconds) else { return false }
        return m >= 0 && m <= 100_800 && s >= 0 && s < 60
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.errorMessage != nil { Section { SaveErrorBanner() } }
                Section {
                    HStack(spacing: 14) {
                        HabitIcon(routine: routine)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(routine.title).font(.headline)
                            Text(HabitCalendar.date(day).formatted(.dateTime.year().month().day().weekday())).font(.caption).foregroundStyle(Palette.muted)
                        }
                    }.padding(.vertical, 6)
                }
                Section("今日の結果") {
                    Picker("結果", selection: $outcome) {
                        Text("できた").tag(Outcome.done)
                        Text("できなかった").tag(Outcome.missed)
                    }.pickerStyle(.segmented).accessibilityIdentifier("record.outcome")
                }
                Section {
                    HStack {
                        Text("実施時間")
                        Spacer()
                        TextField("0", text: $minutes).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 88).focused($focused).accessibilityIdentifier("record.minutes")
                        Text("分").foregroundStyle(Palette.muted)
                        TextField("0", text: $seconds).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 42).focused($focused).accessibilityIdentifier("record.seconds")
                        Text("秒").foregroundStyle(Palette.muted)
                    }
                    HStack {
                        ForEach(Array(Set([routine.targetMinutes, 10, 20, 30])).sorted(), id: \.self) { value in
                            Button("\(value)分") { minutes = String(value); seconds = "0"; focused = false }
                                .font(.subheadline).buttonStyle(.bordered).frame(maxWidth: .infinity)
                        }
                    }.listRowSeparator(.hidden)
                } header: { Text("取り組んだ時間") } footer: {
                    Text("その日の合計時間を入力します。「できなかった」日も、途中まで取り組んだ時間を残せます。")
                }
                Section("ひとことメモ（任意）") {
                    TextField("気づいたこと、次に試したいこと", text: $note, axis: .vertical).lineLimit(3...6).accessibilityIdentifier("record.note")
                }
                if store.record(for: routine, day: day) != nil {
                    Section { Button("未記録に戻す", role: .destructive) { confirmClear = true }.accessibilityIdentifier("record.clear") }
                }
            }
            .navigationTitle("結果を記録").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if store.saveRecord(routine: routine, day: day, outcome: outcome, seconds: (Int(minutes) ?? 0) * 60 + (Int(seconds) ?? 0), note: note) { dismiss() }
                    }.bold().disabled(!valid).accessibilityIdentifier("record.save")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { focused = false } }
            }
            .onAppear {
                if let record = store.record(for: routine, day: day) {
                    outcome = record.outcome; minutes = String(record.seconds / 60); seconds = String(record.seconds % 60); note = record.note
                }
            }
            .confirmationDialog("時間とメモも消去し、未記録に戻しますか？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("未記録に戻す", role: .destructive) { if store.clearRecord(routine: routine, day: day) { dismiss() } }
            }
        }
    }
}

struct TimerView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDiscard = false
    var body: some View {
        NavigationStack {
            if let timer = store.data.timer, let routine = store.data.routines.first(where: { $0.id == timer.routineID }) {
                VStack(spacing: 26) {
                    SaveErrorBanner()
                    Spacer()
                    HabitIcon(routine: routine).scaleEffect(1.35).padding(12)
                    Text(routine.title).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                    Text("今、この時間も積み重なっている。").font(.subheadline).foregroundStyle(Palette.muted)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = timer.elapsed(at: context.date)
                        ZStack {
                            Circle().stroke(Palette.mint, lineWidth: 10)
                            Circle().trim(from: 0, to: min(Double(elapsed) / Double(max(1, routine.targetMinutes) * 60), 1))
                                .stroke(Palette.green, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                            VStack(spacing: 12) {
                                Text(DurationText.clock(elapsed)).font(.system(size: 38, weight: .medium, design: .rounded)).monospacedDigit().accessibilityIdentifier("timer.elapsed")
                                Text("目安 \(routine.targetMinutes)分").font(.subheadline).foregroundStyle(Palette.muted)
                            }
                        }.frame(width: 260, height: 260)
                    }
                    Text("画面を閉じても計測は続きます。\n開始日（\(timer.day)）の時間に加算します。")
                        .font(.caption).foregroundStyle(Palette.muted).multilineTextAlignment(.center).lineSpacing(5)
                    Spacer()
                    VStack(spacing: 16) {
                        Button("できた · 終了して記録") { if store.finishTimer(outcome: .done) { dismiss() } }
                            .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("timer.finish")
                        Button("できなかった · ここまでの時間を記録") { if store.finishTimer(outcome: .missed) { dismiss() } }
                            .font(.subheadline).foregroundStyle(Palette.muted).accessibilityIdentifier("timer.missed")
                        Button("この計測を破棄", role: .destructive) { confirmDiscard = true }.font(.caption).padding(.top, 6)
                    }
                }.padding(28).background(Palette.background)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
                    .confirmationDialog("計測した時間を保存せずに終了しますか？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                        Button("計測を破棄", role: .destructive) { store.cancelTimer(); if store.data.timer == nil { dismiss() } }
                    }
            } else { Text("計測中のルーティンはありません。") }
        }
    }
}
