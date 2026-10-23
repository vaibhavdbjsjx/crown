import Charts
import SwiftData
import SwiftUI

extension Int {
    var roman: String {
        let map = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = self, out = ""
        for (v, s) in map { while n >= v { out += s; n -= v } }
        return out
    }
}

struct HomeView: View {
    @EnvironmentObject private var account: Account
    @Environment(\.startScan) private var startScan
    @Query(sort: \Scan.date) private var scans: [Scan]
    @Query(sort: \RoutineItem.sortOrder) private var routine: [RoutineItem]
    @State private var shown = false
    @State private var showShare = false

    private var latest: Scan? { scans.last }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header.reveal(shown, index: 0)
                        if let latest {
                            hero(latest).reveal(shown, index: 1)
                            metricTrio(latest).reveal(shown, index: 2)
                            CheckInCard(lastScan: latest.date).reveal(shown, index: 3)
                            InsightsCard(scans: scans, routine: routine).reveal(shown, index: 4)
                            if !routine.isEmpty { TodayRoutineCard(items: routine).reveal(shown, index: 5) }
                            Button { showShare = true } label: {
                                Label("Share progress card", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .reveal(shown, index: 6)
                        } else {
                            emptyState.reveal(shown, index: 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                if let scan = scans.first(where: { $0.id == id }) { ScanResultView(scan: scan) }
            }
        }
        .sheet(isPresented: $showShare) { ShareCardSheet() }
        .onAppear { shown = true }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")
        if let name = account.profile?.firstName, !name.isEmpty { return "\(part),\n\(name)." }
        return "\(part)."
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                Text(greeting)
                    .font(Typo.display(34))
                    .foregroundStyle(Theme.ivory)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "crown.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.goldGradient)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.05), in: Circle())
                .overlay(Circle().strokeBorder(Theme.edgeGradient))
        }
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScanIllustration().frame(maxWidth: .infinity).frame(height: 280)
            Eyebrow("Step one", color: Theme.champagne)
            Text("Set your\nbaseline.")
                .font(Typo.display(40))
            Text("A two-minute guided scan of your hairline, temples and crown. Every check-in after this is measured against it.")
                .font(Typo.callout).foregroundStyle(Theme.secondary).lineSpacing(3)
            VStack(alignment: .leading, spacing: 14) {
                tip("viewfinder", "Live framing makes every photo comparable")
                tip("sun.max", "Face a window or soft, even light")
                tip("hand.raised", "Pull hair back off your forehead")
                tip("lock", "Analysed on this iPhone, never uploaded")
            }
            .card()
            Button("Take your first scan · Free") { startScan() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.champagne).frame(width: 22)
            Text(text).font(Typo.subhead).foregroundStyle(Theme.ivory.opacity(0.9))
        }
    }

    private func hero(_ scan: Scan) -> some View {
        NavigationLink(value: scan.id) {
            VStack(spacing: 18) {
                HStack {
                    Eyebrow("Latest scan · \(scan.date.formatted(.dateTime.month(.abbreviated).day()))")
                    Spacer()
                    if scans.count > 1 { DeltaBadge(delta: scan.score - scans[scans.count - 2].score) }
                }
                ScoreDial(score: scan.score, size: 220)
                VStack(spacing: 6) {
                    Text("Stage \(scan.stage.roman)")
                        .font(Typo.display(26))
                        .foregroundStyle(Theme.goldGradient)
                    Text(Scoring.stageSummary(scan.stage))
                        .font(Typo.subhead).foregroundStyle(Theme.secondary)
                }
                if let q = scan.quality, q < 70 {
                    Label("Low photo quality. Treat this reading with caution.", systemImage: "exclamationmark.triangle.fill")
                        .font(Typo.caption).foregroundStyle(Theme.ember)
                }
                HStack(spacing: 6) {
                    Text("View full analysis")
                    Image(systemName: "arrow.right")
                }
                .font(Typo.caption.weight(.semibold))
                .foregroundStyle(Theme.champagne)
            }
            .frame(maxWidth: .infinity)
            .card(padding: 22, radius: 32)
        }
        .buttonStyle(PressableStyle())
    }

    private func metricTrio(_ scan: Scan) -> some View {
        HStack(spacing: 10) {
            MetricTile(title: "Hairline", value: scan.hairlineScore, symbol: "line.diagonal")
            MetricTile(title: "Temples", value: scan.templeScore, symbol: "chevron.up")
            MetricTile(title: "Crown", value: scan.crownScore, symbol: "circle.dotted")
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: Double?
    let symbol: String
    @State private var fill = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.tertiary)
            Text(value.map { "\(Int($0.rounded()))" } ?? "–")
                .font(Typo.numeral(30))
                .foregroundStyle(Theme.ivory)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(value.map(Theme.scoreColor) ?? .clear).frame(width: geo.size.width * fill / 100)
                }
            }
            .frame(height: 3)
            Eyebrow(title)
        }
        .card(padding: 16, radius: 22)
        .onAppear { withAnimation(.easeOut(duration: 1.1).delay(0.3)) { fill = value ?? 0 } }
    }
}

struct CheckInCard: View {
    let lastScan: Date
    @Environment(\.startScan) private var startScan

    var body: some View {
        let cal = Calendar.current
        let next = cal.date(byAdding: .day, value: 30, to: lastScan) ?? lastScan
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: next)).day ?? 0
        let progress = Double(30 - max(days, 0)) / 30
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 5)
                Circle().trim(from: 0, to: progress)
                    .stroke(Theme.goldGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text("\(max(days, 0))").font(Typo.numeral(24, weight: .regular))
                    Text("days").font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.tertiary)
                }
            }
            .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Monthly check-in")
                Text(days > 0 ? "Next scan \(next.formatted(.dateTime.month(.abbreviated).day()))" : "Your check-in is due")
                    .font(Typo.title2)
                Button(days > 0 ? "Scan early" : "Start check-in") { startScan() }
                    .font(Typo.caption.weight(.semibold))
                    .foregroundStyle(Theme.champagne)
            }
            Spacer(minLength: 0)
        }
        .card()
    }
}

struct InsightsCard: View {
    let scans: [Scan]
    let routine: [RoutineItem]

    private var insights: [(String, String, Color)] {
        var out: [(String, String, Color)] = []
        if let first = scans.first, let last = scans.last, scans.count > 1 {
            let days = Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 0
            let delta = last.score - first.score
            if abs(delta) < 3 {
                out.append(("checkmark.seal.fill", "Your score has held steady for \(days) days.", Theme.sage))
            } else if delta > 0 {
                out.append(("arrow.up.right", "Up \(Int(delta.rounded())) points since your first scan \(days) days ago.", Theme.sage))
            } else {
                out.append(("arrow.down.right", "Down \(Int(abs(delta).rounded())) points over \(days) days. Check lighting matched before reading into it.", Theme.ember))
            }
        } else {
            out.append(("calendar", "Baseline saved. Real change shows over months, so your next scan is the first comparison.", Theme.champagne))
        }
        if let q = scans.last?.quality, q < 70 {
            out.append(("sun.max.fill", "Last photo quality was \(Int(q))%. Retake in soft daylight for a cleaner reading.", Theme.ember))
        }
        if !routine.isEmpty {
            let cal = Calendar.current
            let daily = routine.filter { $0.intervalDays == 1 }
            if !daily.isEmpty {
                let done = (0..<14).reduce(0) { acc, d in
                    let day = cal.date(byAdding: .day, value: -d, to: Date())!
                    return acc + daily.filter { $0.isDone(on: day) }.count
                }
                let pct = Int(Double(done) / Double(daily.count * 14) * 100)
                out.append(("flame.fill", "Routine adherence: \(pct)% over the last 14 days.", pct >= 80 ? Theme.sage : Theme.champagne))
            }
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Insights")
            ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.0)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(insight.2)
                        .frame(width: 28, height: 28)
                        .background(insight.2.opacity(0.12), in: Circle())
                    Text(insight.1).font(Typo.subhead).foregroundStyle(Theme.ivory.opacity(0.9)).lineSpacing(2)
                }
            }
        }
        .card()
    }
}

struct TodayRoutineCard: View {
    let items: [RoutineItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("Today's routine")
                Spacer()
                Text("\(items.filter { $0.isDone(on: Date()) }.count)/\(items.count)")
                    .font(Typo.mono).foregroundStyle(Theme.tertiary)
            }
            ForEach(items.prefix(4)) { item in
                RoutineCheckRow(item: item, compact: true)
            }
        }
        .card()
    }
}

struct TrendChart: View {
    let scans: [Scan]
    var journal: [JournalEntry] = []
    var height: CGFloat = 190

    var body: some View {
        Chart {
            ForEach(journal) { entry in
                RuleMark(x: .value("Date", entry.date))
                    .foregroundStyle(Theme.champagne.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .annotation(position: .top, alignment: .center) {
                        Image(systemName: entry.journalKind.symbol).font(.system(size: 9)).foregroundStyle(Theme.champagne)
                    }
            }
            ForEach(scans) { scan in
                AreaMark(x: .value("Date", scan.date), y: .value("Score", scan.score))
                    .foregroundStyle(LinearGradient(colors: [Theme.champagne.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", scan.date), y: .value("Score", scan.score))
                    .foregroundStyle(Theme.goldGradient)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", scan.date), y: .value("Score", scan.score))
                    .foregroundStyle(Theme.ivory)
                    .symbolSize(30)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel().foregroundStyle(Theme.tertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Theme.tertiary)
            }
        }
        .frame(height: height)
    }
}
