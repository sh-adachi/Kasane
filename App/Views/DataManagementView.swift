import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var exportDocument = HabitFileDocument(data: Data())
    @State private var exportType: UTType = .json
    @State private var exportName = ""
    @State private var showExport = false
    @State private var showImport = false
    @State private var candidate: BackupCandidate?
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("大切な積み重ねを、手元に。", systemImage: "externaldrive.badge.checkmark")
                        .font(.headline).foregroundStyle(Palette.green)
                    Text("ルーティン \(store.data.routines.count)件 · 記録 \(store.data.records.count)件")
                    Text("累積 \(DurationText.short(HabitAnalytics.totalSeconds(data: store.data)))").foregroundStyle(Palette.muted)
                    if store.isDemo { Text("体験用データです。実際の記録とは別に扱います。").font(.caption).foregroundStyle(Palette.orange) }
                }
                Section {
                    Button { prepareExport(csv: false) } label: { Label("バックアップを保存", systemImage: "square.and.arrow.up") }
                        .disabled(store.readOnly).accessibilityIdentifier("data.exportBackup")
                    Button { prepareExport(csv: true) } label: { Label("記録をCSVで書き出す", systemImage: "tablecells") }
                        .disabled(store.readOnly).accessibilityIdentifier("data.exportCSV")
                } header: { Text("書き出し") } footer: {
                    Text("バックアップはルーティン・曜日の履歴・記録・目標を含みます。計測中のタイマーは含みません。CSVは表計算アプリで振り返るための記録一覧です。")
                }
                Section {
                    Button { showImport = true } label: { Label("バックアップを読み込む", systemImage: "square.and.arrow.down") }
                        .disabled(store.data.timer != nil).accessibilityIdentifier("data.importBackup")
                    if store.hasRecoveryBackup {
                        Button {
                            do { candidate = BackupCandidate(name: "前回の復元前のデータ", data: try store.recoveryData()) }
                            catch { self.error = error.localizedDescription }
                        } label: { Label("前回の復元前のデータに戻す", systemImage: "arrow.uturn.backward") }
                            .disabled(store.data.timer != nil).accessibilityIdentifier("data.recover")
                    }
                } header: { Text("復元") } footer: {
                    Text(store.data.timer != nil
                         ? "復元する前に、計測中・一時停止中のタイマーを終了してください。"
                         : "内容を確認してから、現在のデータを置き換えます。置き換え前のデータは端末内に1世代保存します。CSVからは復元できません。")
                }
                Section("リマインダー") {
                    Text(store.reminderStatusMessage).font(.subheadline)
                    Text("各ルーティンの「取り組む時刻」で通知を設定できます。休止中の習慣は通知しません。")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                if let message { Section { Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(Palette.green).accessibilityIdentifier("data.success") } }
                Section {
                    Text("バックアップには習慣の名前やメモが含まれます。保存先は自分で選べます。アプリを削除すると端末内の記録も消えるため、必要に応じてファイルへ保存してください。")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
            }
            .navigationTitle("データと設定").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
            .task { await store.refreshReminders() }
            .fileExporter(isPresented: $showExport, document: exportDocument, contentType: exportType, defaultFilename: exportName) { result in
                switch result {
                case .success: message = "ファイルに保存しました。"
                case .failure(let failure): error = "保存できませんでした。\n\(failure.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 10 * 1024 * 1024 {
                        throw HabitDataError.invalid("10MB以下のバックアップを選んでください。")
                    }
                    let incoming = try HabitTransfer.decodeBackup(Data(contentsOf: url))
                    candidate = BackupCandidate(name: url.lastPathComponent, data: incoming)
                } catch { self.error = "読み込めませんでした。現在の記録は変更していません。\n\(error.localizedDescription)" }
            }
            .sheet(item: $candidate) { selection in
                BackupPreviewView(candidate: selection) {
                    message = "バックアップを復元しました。"
                    candidate = nil
                }
            }
            .alert("ファイルを確認してください", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("閉じる", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private func prepareExport(csv: Bool) {
        do {
            exportDocument = HabitFileDocument(data: csv ? Data(HabitTransfer.csv(store.data).utf8) : try HabitTransfer.encodeBackup(store.data))
            exportType = csv ? .commaSeparatedText : .json
            exportName = "Kasane-\(csv ? "records" : "backup")-\(HabitCalendar.dayKey(Date()))"
            showExport = true
        } catch { self.error = error.localizedDescription }
    }
}

private struct HabitFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct BackupCandidate: Identifiable {
    let id = UUID()
    let name: String
    let data: HabitData
}

private struct BackupPreviewView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let candidate: BackupCandidate
    let onRestored: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("読み込むファイル") {
                    Text(candidate.name).font(.headline)
                    LabeledContent("ルーティン", value: "\(candidate.data.routines.count)件")
                    LabeledContent("記録", value: "\(candidate.data.records.count)件")
                    LabeledContent("累積時間", value: DurationText.short(HabitAnalytics.totalSeconds(data: candidate.data)))
                    if let first = candidate.data.records.map(\.day).min(), let last = candidate.data.records.map(\.day).max() {
                        LabeledContent("記録期間", value: "\(first) 〜 \(last)")
                    }
                }
                Section {
                    Text("現在のルーティン\(store.data.routines.count)件と記録\(store.data.records.count)件を、このファイルの内容で置き換えます。")
                    Text(store.isDemo ? "体験中は、体験用のデータだけを置き換えます。" : "復元前のデータは端末内に残り、「前回の復元前のデータに戻す」から戻せます。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Text("計測中のタイマーは復元しません。通知は、このiPhoneで許可されている場合だけ設定します。")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                if store.errorMessage != nil { Section { SaveErrorBanner() } }
                Section {
                    Button("このバックアップで復元する", role: .destructive) {
                        if store.restoreBackup(candidate.data) { onRestored() }
                    }.disabled(store.data.timer != nil).accessibilityIdentifier("data.confirmRestore")
                }
            }
            .navigationTitle("復元する内容を確認").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } } }
        }
    }
}
