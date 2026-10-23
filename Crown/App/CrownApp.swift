import SwiftData
import SwiftUI

@main
struct CrownApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
        }
        .modelContainer(for: [Scan.self, RoutineItem.self, RoutineLog.self])
    }
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        ZStack {
            if hasOnboarded {
                MainTabView().transition(.opacity)
            } else {
                OnboardingView { withAnimation(.easeInOut(duration: 0.5)) { hasOnboarded = true } }
                    .transition(.opacity)
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "crown.fill") }
            HistoryView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            RoutineView()
                .tabItem { Label("Routine", systemImage: "checklist") }
        }
    }
}

/// Covers Pro-only content with a tasteful lock that opens the paywall.
struct ProLocked: ViewModifier {
    @EnvironmentObject private var store: Store
    let title: String
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        if store.isPro {
            content
        } else {
            content
                .blur(radius: 10)
                .allowsHitTesting(false)
                .overlay {
                    Button { showPaywall = true } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "lock.fill").font(.system(size: 22)).foregroundStyle(Theme.goldGradient)
                            Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                            Text("Unlock with Crown Pro").font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.gold)
                        }
                        .padding(22)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}

extension View {
    func proLocked(_ title: String) -> some View { modifier(ProLocked(title: title)) }
}
