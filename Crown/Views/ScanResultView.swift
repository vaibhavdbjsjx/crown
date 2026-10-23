import SwiftData
import SwiftUI

struct ScanResultView: View {
    let scan: Scan
    var isNew = false
    var onDone: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Scan.date) private var scans: [Scan]
    @State private var shown = false
    @State private var confirmDelete = false
    @State private var showShare = false
    @State private var angle: ScanAngle = .front
    @State private var showMarkers = true
    @State private var note = ""

    private var previous: Scan? { scans.last { $0.date < scan.date } }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(isNew ? "Scan complete" : scan.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()), color: Theme.champagne)
                        Text(isNew ? "Here's where\nyou stand." : "Scan details")
                            .font(Typo.display(36))
                    }
                    .padding(.top, isNew ? 30 : 4)
                    .reveal(shown)

                    summary.reveal(shown, index: 1)
                    photoCard.reveal(shown, index: 2)
                    metrics.reveal(shown, index: 3)
                    qualityCard.reveal(shown, index: 4)
                    noteCard.reveal(shown, index: 5)
                    Text(Legal.disclaimer).font(Typo.caption).foregroundStyle(Theme.tertiary).padding(.horizontal, 4)
                    if isNew {
                        VStack(spacing: 10) {
                            Button { showShare = true } label: { Label("Share progress card", systemImage: "square.and.arrow.up") }
                                .buttonStyle(SecondaryButtonStyle())
                            Button("Done") { saveNote(); onDone?() }.buttonStyle(PrimaryButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, isNew ? 30 : 120)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isNew {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showShare = true } label: { Label("Share progress card", systemImage: "square.and.arrow.up") }
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete scan", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Theme.ivory) }
                }
            }
        }
        .confirmationDialog("Delete this scan and its photos?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete scan", role: .destructive) {
                PhotoStore.delete(scan.allPhotos)
                context.delete(scan)
                try? context.save()
                dismiss()
            }
        }
        .sheet(isPresented: $showShare) { ShareCardSheet() }
        .onAppear {
            note = scan.note
            shown = true
        }
        .onDisappear { saveNote() }
    }

    private func saveNote() {
        guard note != scan.note else { return }
        scan.note = note
        try? context.save()
    }

    private var summary: some View {
        VStack(spacing: 18) {
            ScoreDial(score: scan.score, size: 210)
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(scan.stage.roman).font(Typo.display(30)).foregroundStyle(Theme.goldGradient)
                    Eyebrow("Stage")
                }
                .frame(maxWidth: .infinity)
                Rectangle().fill(Theme.stroke).frame(width: 1, height: 44)
                VStack(spacing: 4) {
                    if let previous { DeltaBadge(delta: scan.score - previous.score) } else {
                        Text("Baseline").font(Typo.title2).foregroundStyle(Theme.ivory)
                    }
                    Eyebrow("vs last scan")
                }
                .frame(maxWidth: .infinity)
            }
            Text(Scoring.stageSummary(scan.stage)).font(Typo.subhead).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 22, radius: 32)
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Photos")
                Spacer()
                if angle == .front && scan.markers.count >= 7 {
                    Button { withAnimation(.easeInOut) { showMarkers.toggle() } } label: {
                        Label(showMarkers ? "Hide markers" : "Show markers", systemImage: showMarkers ? "eye.slash" : "eye")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.champagne)
                }
            }
            ZStack {
                if let image = PhotoStore.load(scan.photo(for: angle)) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .overlay {
                            if angle == .front && showMarkers {
                                MarkerOverlay(markers: scan.markers, aspect: Double(image.size.width / image.size.height))
                                    .transition(.opacity)
                            }
                        }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera").font(.system(size: 22))
                        Text("No \(angle.shortTitle.lowercased()) photo in this scan").font(Typo.caption)
                    }
                    .foregroundStyle(Theme.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.ink3)
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            AnglePicker(angle: $angle)
            Label("Stored only on this iPhone", systemImage: "lock.fill").font(Typo.micro).foregroundStyle(Theme.tertiary)
        }
        .card()
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow("Measurements")
            MetricRow(title: "Hairline position",
                      detail: scan.hairlineRatio.map { String(format: "Forehead height is %.0f%% of brow-to-chin", $0 * 100) },
                      score: scan.hairlineScore, previous: previous?.hairlineScore)
            MetricRow(title: "Temple recession",
                      detail: scan.templeRatio.map { String(format: "Temples sit %.2f× the midline height", $0) },
                      score: scan.templeScore, previous: previous?.templeScore)
            MetricRow(title: "Crown density",
                      detail: scan.crownCoverage.map { String(format: "%.0f%% estimated hair coverage", $0 * 100) },
                      score: scan.crownScore, previous: previous?.crownScore, missing: "Add a crown photo next check-in")
        }
        .card()
    }

    @ViewBuilder
    private var qualityCard: some View {
        if let q = scan.quality {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 4)
                    Circle().trim(from: 0, to: q / 100)
                        .stroke(q >= 70 ? Theme.sage : Theme.ember, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(q))").font(Typo.numeral(16, weight: .regular))
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Photo quality")
                    Text(q >= 85 ? "Excellent, very comparable" : (q >= 70 ? "Good, reliable for comparison" : "Low, compare with caution"))
                        .font(Typo.subhead).foregroundStyle(Theme.ivory)
                }
                Spacer()
            }
            .card()
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Note")
            TextField("Anything worth remembering about this scan?", text: $note, axis: .vertical)
                .font(Typo.callout)
                .lineLimit(1...4)
        }
        .card()
    }
}

struct MetricRow: View {
    let title: String
    let detail: String?
    let score: Double?
    var previous: Double?
    var missing = "Not measured"
    @State private var fill: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Typo.headline)
                Spacer()
                if let score, let previous { DeltaBadge(delta: score - previous) }
                Text(score.map { "\(Int($0.rounded()))" } ?? "–")
                    .font(Typo.numeral(24, weight: .regular))
                    .foregroundStyle(score.map(Theme.scoreColor) ?? Theme.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(Theme.goldGradient).frame(width: geo.size.width * fill / 100)
                    if let previous {
                        Rectangle().fill(Theme.ivory.opacity(0.6)).frame(width: 2, height: 10)
                            .offset(x: geo.size.width * previous / 100 - 1)
                    }
                }
            }
            .frame(height: 4)
            Text(detail ?? missing).font(Typo.caption).foregroundStyle(Theme.tertiary)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.1).delay(0.25)) { fill = score ?? 0 } }
    }
}
