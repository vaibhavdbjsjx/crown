import SwiftData
import SwiftUI

struct ScanResultView: View {
    let scan: Scan
    var isNew = false
    var onDone: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Scan.date) private var scans: [Scan]
    @State private var appeared = false
    @State private var confirmDelete = false
    @State private var showShare = false

    private var previous: Scan? {
        scans.last { $0.date < scan.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isNew {
                    Text("Scan complete")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .padding(.top, 24)
                }
                summary
                metrics
                photos
                Text(Legal.disclaimer)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.horizontal, 4)
                actions
            }
            .padding(20)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(isNew ? "" : scan.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isNew {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showShare = true } label: { Label("Share progress card", systemImage: "square.and.arrow.up") }
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete scan", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .confirmationDialog("Delete this scan and its photos?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                PhotoStore.delete(scan.allPhotos)
                context.delete(scan)
                try? context.save()
                dismiss()
            }
        }
        .sheet(isPresented: $showShare) { ShareCardSheet() }
        .onAppear { withAnimation(.easeOut(duration: 0.5).delay(0.05)) { appeared = true } }
    }

    private var summary: some View {
        HStack(spacing: 20) {
            ScoreRing(score: scan.score).frame(width: 118, height: 118)
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(text: "Crown stage")
                Text("Stage \(scan.stage)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.goldGradient)
                Text(Scoring.stageSummary(scan.stage))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                if let previous {
                    let delta = scan.score - previous.score
                    Label(abs(delta) < 2 ? "Stable since last scan" : String(format: "%@%.0f since last scan", delta > 0 ? "+" : "", delta),
                          systemImage: abs(delta) < 2 ? "equal.circle.fill" : (delta > 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(abs(delta) < 2 || delta > 0 ? Theme.positive : Theme.warning)
                }
            }
        }
        .card()
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "Measurements")
            MetricRow(title: "Hairline position", detail: scan.hairlineRatio.map { String(format: "Forehead %.0f%% of lower face", $0 * 100) }, score: scan.hairlineScore)
            MetricRow(title: "Temple recession", detail: scan.templeRatio.map { String(format: "Temples %.2f× midline height", $0) }, score: scan.templeScore)
            MetricRow(title: "Crown density", detail: scan.crownCoverage.map { String(format: "%.0f%% hair coverage", $0 * 100) }, score: scan.crownScore,
                      missing: "Add a crown photo next scan")
        }
        .card()
    }

    private var photos: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Photos")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ScanAngle.allCases) { angle in
                        if let image = PhotoStore.load(scan.photo(for: angle)) {
                            VStack(spacing: 6) {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 120, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                Text(angle.shortTitle).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            Label("Stored only on this iPhone", systemImage: "lock.fill")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.tertiary)
        }
        .card()
    }

    @ViewBuilder
    private var actions: some View {
        if isNew {
            VStack(spacing: 10) {
                Button("Share progress card") { showShare = true }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Done") { onDone?() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

struct MetricRow: View {
    let title: String
    let detail: String?
    let score: Double?
    var missing = "Not measured"
    @State private var fill: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer()
                Text(score.map { "\(Int($0.rounded()))" } ?? "–")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(score.map(Theme.scoreColor) ?? Theme.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(score.map(Theme.scoreColor) ?? .clear).frame(width: geo.size.width * fill / 100)
                }
            }
            .frame(height: 6)
            Text(detail ?? missing).font(.system(size: 12, design: .rounded)).foregroundStyle(Theme.tertiary)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.2)) { fill = score ?? 0 } }
    }
}
