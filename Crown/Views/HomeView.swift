import Charts
import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: Store
    @Query(sort: \Scan.date) private var scans: [Scan]
    @State private var showScan = false
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var showShare = false

    private var latest: Scan? { scans.last }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let latest {
                        NavigationLink { ScanResultView(scan: latest) } label: { latestCard(latest) }
                            .buttonStyle(.plain)
                        checkInCard(latest)
                        if scans.count >= 2 {
                            TrendCard(scans: scans).proLocked("Your trend line")
                        }
                        Button { showShare = true } label: {
                            Label("Share progress card", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        emptyState
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showScan) { ScanFlowView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showShare) { ShareCardSheet() }
    }

    private func startScan() {
        if scans.isEmpty || store.isPro { showScan = true } else { showPaywall = true }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill").foregroundStyle(Theme.goldGradient)
                Text("Crown").font(.system(size: 28, weight: .bold, design: .rounded))
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.surface, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle().fill(Theme.gold.opacity(0.08)).frame(width: 190, height: 190)
                Circle().strokeBorder(Theme.goldGradient, style: StrokeStyle(lineWidth: 2, dash: [6, 6])).frame(width: 150, height: 190 * 0.9)
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(Theme.goldGradient)
            }
            .padding(.top, 30)
            VStack(spacing: 8) {
                Text("Start your baseline")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("A two-minute guided scan of your hairline, temples and crown. Repeat monthly to see real change, not mirror guesswork.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 12) {
                tip("viewfinder", "Guided framing keeps every photo comparable")
                tip("sun.max.fill", "Stand facing a window or soft, even light")
                tip("lock.fill", "Photos and analysis stay on this iPhone")
            }
            .card()
            Button("Take first scan (free)", action: startScan)
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.gold).frame(width: 22)
            Text(text).font(.system(.subheadline, design: .rounded))
        }
    }

    private func latestCard(_ scan: Scan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionTitle(text: "Latest scan")
                Spacer()
                Text(scan.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.tertiary)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.tertiary)
            }
            HStack(spacing: 20) {
                ScoreRing(score: scan.score).frame(width: 108, height: 108)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stage \(scan.stage)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.goldGradient)
                    mini("Hairline", scan.hairlineScore)
                    mini("Temples", scan.templeScore)
                    mini("Crown", scan.crownScore)
                }
            }
        }
        .card()
    }

    private func mini(_ title: String, _ value: Double?) -> some View {
        HStack {
            Text(title).font(.system(size: 13, design: .rounded)).foregroundStyle(Theme.secondary)
            Spacer()
            Text(value.map { "\(Int($0.rounded()))" } ?? "–")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(value.map(Theme.scoreColor) ?? Theme.tertiary)
        }
    }

    private func checkInCard(_ scan: Scan) -> some View {
        let next = Calendar.current.date(byAdding: .day, value: 30, to: scan.date) ?? scan.date
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: next)).day ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionTitle(text: "Monthly check-in")
                    Text(days > 0 ? "In \(days) day\(days == 1 ? "" : "s")" : "Due today")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
                Spacer()
                Image(systemName: "calendar").font(.system(size: 22)).foregroundStyle(Theme.gold)
            }
            ProgressView(value: Double(30 - max(days, 0)), total: 30).tint(Theme.gold)
            Text("Monthly scans in the same light show real change. Daily checks mostly show noise.")
                .font(.system(size: 12, design: .rounded)).foregroundStyle(Theme.tertiary)
            Button(days > 0 ? "Scan now anyway" : "Start check-in", action: startScan)
                .buttonStyle(days > 0 ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
        }
        .card()
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

struct TrendCard: View {
    let scans: [Scan]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(text: "Trend")
                Spacer()
                if let first = scans.first, let last = scans.last {
                    let delta = last.score - first.score
                    Text(abs(delta) < 2 ? "Stable" : String(format: "%@%.0f", delta > 0 ? "+" : "", delta))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(abs(delta) < 2 || delta > 0 ? Theme.positive : Theme.warning)
                }
            }
            Chart(scans) { scan in
                AreaMark(x: .value("Date", scan.date), y: .value("Score", scan.score))
                    .foregroundStyle(LinearGradient(colors: [Theme.gold.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", scan.date), y: .value("Score", scan.score))
                    .foregroundStyle(Theme.gold)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", scan.date), y: .value("Score", scan.score))
                    .foregroundStyle(Theme.gold)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
            .frame(height: 170)
        }
        .card()
    }
}
