import SwiftData
import SwiftUI

@main
struct CrownApp: App {
    @StateObject private var store = Store()
    @StateObject private var account = Account()
    @StateObject private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        let serif = UIFont.systemFont(ofSize: 17, weight: .semibold).fontDescriptor.withDesign(.serif)
        let large = UIFont.systemFont(ofSize: 34, weight: .regular).fontDescriptor.withDesign(.serif)
        nav.titleTextAttributes = [.foregroundColor: UIColor(Theme.ivory),
                                   .font: serif.map { UIFont(descriptor: $0, size: 17) } ?? UIFont.systemFont(ofSize: 17)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.ivory),
                                        .font: large.map { UIFont(descriptor: $0, size: 34) } ?? UIFont.systemFont(ofSize: 34)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(account)
                .environmentObject(lock)
                .preferredColorScheme(.dark)
                .tint(Theme.champagne)
                .onAppear { lock.lockIfNeeded() }
        }
        .modelContainer(for: [Scan.self, RoutineItem.self, RoutineLog.self, JournalEntry.self, ShedLog.self])
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.lockIfNeeded() }
        }
    }
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @EnvironmentObject private var lock: AppLock
    @Environment(\.modelContext) private var context

    init() {}

    var body: some View {
        ZStack {
            if hasOnboarded {
                MainTabView().transition(.opacity)
            } else {
                OnboardingView { withAnimation(.easeInOut(duration: 0.6)) { hasOnboarded = true } }
                    .transition(.opacity)
            }
            if lock.locked {
                LockScreen().transition(.opacity).zIndex(10)
            }
        }
        #if DEBUG
        .task { DemoData.seed(context); if DemoData.isEnabled { hasOnboarded = true } }
        #endif
    }
}

// MARK: - Tabs

enum AppTab: Int, CaseIterable {
    case today, progress, routine, profile
    var title: String {
        switch self {
        case .today: "Today"
        case .progress: "Progress"
        case .routine: "Routine"
        case .profile: "You"
        }
    }
    var symbol: String {
        switch self {
        case .today: "sun.horizon"
        case .progress: "chart.xyaxis.line"
        case .routine: "checklist"
        case .profile: "person.crop.circle"
        }
    }
}

struct StartScanAction {
    let run: () -> Void
    func callAsFunction() { run() }
}

private struct StartScanKey: EnvironmentKey {
    static let defaultValue = StartScanAction {}
}

extension EnvironmentValues {
    var startScan: StartScanAction {
        get { self[StartScanKey.self] }
        set { self[StartScanKey.self] = newValue }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: Store
    @Query private var scans: [Scan]
    @Environment(\.modelContext) private var context
    @State private var tab: AppTab = .today
    @State private var showScan = false
    @State private var showPaywall = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                HomeView().tag(AppTab.today).toolbar(.hidden, for: .tabBar)
                ProgressHubView().tag(AppTab.progress).toolbar(.hidden, for: .tabBar)
                RoutineView().tag(AppTab.routine).toolbar(.hidden, for: .tabBar)
                ProfileView().tag(AppTab.profile).toolbar(.hidden, for: .tabBar)
            }
            FloatingTabBar(tab: $tab) { startScan() }
                .padding(.horizontal, 18)
                .padding(.bottom, 4)
        }
        .ignoresSafeArea(.keyboard)
        .environment(\.startScan, StartScanAction { startScan() })
        .fullScreenCover(isPresented: $showScan) { ScanFlowView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            #if DEBUG
            tab = DemoData.initialTab
            if ProcessInfo.processInfo.arguments.contains("-paywall") { showPaywall = true }
            #endif
        }
    }

    private func startScan() {
        Haptics.tap()
        if scans.isEmpty || store.isPro { showScan = true } else { showPaywall = true }
    }
}

struct FloatingTabBar: View {
    @Binding var tab: AppTab
    let onScan: () -> Void
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            item(.today)
            item(.progress)
            Button(action: onScan) {
                ZStack {
                    Circle().fill(Theme.goldGradient).frame(width: 58, height: 58)
                        .shadow(color: Theme.champagne.opacity(0.45), radius: 14, y: 4)
                    Image(systemName: "viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("New scan")
            .frame(maxWidth: .infinity)
            .offset(y: -10)
            item(.routine)
            item(.profile)
        }
        .padding(.horizontal, 8)
        .frame(height: 66)
        .background {
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Theme.ink2.opacity(0.75)))
                .overlay(Capsule().strokeBorder(Theme.edgeGradient))
                .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
        }
    }

    private func item(_ t: AppTab) -> some View {
        let selected = tab == t
        return Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tab = t }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: t.symbol)
                    .font(.system(size: 18, weight: selected ? .semibold : .regular))
                    .symbolEffect(.bounce, value: selected)
                Text(t.title).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selected ? Theme.champagne : Theme.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if selected {
                    Capsule().fill(Theme.champagne.opacity(0.09)).matchedGeometryEffect(id: "tab", in: ns)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.title)
    }
}

// MARK: - Pro gating

/// Covers Pro-only content with a lock that opens the paywall.
struct ProLocked: ViewModifier {
    @EnvironmentObject private var store: Store
    let title: String
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        if store.isPro {
            content
        } else {
            content
                .blur(radius: 12)
                .allowsHitTesting(false)
                .overlay {
                    Button { showPaywall = true } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "lock.fill").font(.system(size: 18)).foregroundStyle(Theme.goldGradient)
                            Text(title).font(Typo.title2).foregroundStyle(Theme.ivory).multilineTextAlignment(.center)
                            Text("Unlock with Crown Pro").font(Typo.caption.weight(.semibold)).foregroundStyle(Theme.champagne)
                        }
                        .padding(.horizontal, 24).padding(.vertical, 20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.edgeGradient))
                    }
                    .buttonStyle(PressableStyle())
                }
                .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}

extension View {
    func proLocked(_ title: String) -> some View { modifier(ProLocked(title: title)) }
}
