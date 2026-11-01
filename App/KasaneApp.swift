import SwiftUI

@main
struct KasaneApp: App {
    @State private var store = HabitStore()
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Palette.green).preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        @Bindable var store = store
        TabView {
            TodayView().tabItem { Label("今日", systemImage: "square.grid.2x2") }
            NavigationStack { KasaneRoutinesView() }.tabItem { Label("ルーティン", systemImage: "calendar") }
            KasaneProgressView().tabItem { Label("積み重ね", systemImage: "chart.bar.xaxis") }
            KasaneHistoryView().tabItem { Label("履歴", systemImage: "calendar.badge.clock") }
        }
        .task { await store.refreshReminders() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refreshReminders() } }
        }
        .alert("保存を確認してください", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("閉じる", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .sheet(isPresented: $store.showTimer) { TimerView() }
    }
}
