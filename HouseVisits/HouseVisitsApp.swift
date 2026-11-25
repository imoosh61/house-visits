import SwiftUI

@main
struct HouseVisitsApp: App {
    @StateObject private var store = Store()
    @StateObject private var lock = AppLock()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .accessibilityHidden(!lock.unlocked)
                if !lock.unlocked {
                    LockView()
                }
                if phase != .active {
                    PrivacyCover()
                }
            }
            .environmentObject(store)
            .environmentObject(lock)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Fmt.locale)
            .environment(\.calendar, Calendar(identifier: .gregorian))
            .onChange(of: phase) { newPhase in
                if newPhase == .background {
                    lock.lock()
                } else if newPhase == .active {
                    lock.authenticate()
                }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        TabView {
            HousesView()
                .tabItem { Label("البيوت", systemImage: "house.fill") }
            TodayView()
                .tabItem { Label("اليوم", systemImage: "calendar") }
                .badge(store.pending.count)
        }
    }
}
