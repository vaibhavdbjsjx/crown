import SwiftData
import SwiftUI

struct ShareCardContent {
    let headline: String
    let subline: String
    let score: Int
    let stage: Int
    let scanCount: Int

    init(scans: [Scan]) {
        let sorted = scans.sorted { $0.date < $1.date }
        scanCount = sorted.count
        score = Int((sorted.last?.score ?? 0).rounded())
        stage = sorted.last?.stage ?? 1
        guard let first = sorted.first, let last = sorted.last, sorted.count > 1 else {
            headline = "Baseline set"
            subline = "Day one of tracking my hairline"
            return
        }
        let days = max(1, Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1)
        let delta = last.score - first.score
        if abs(delta) < 3 {
            headline = "Hairline stable for \(days) days"
        } else if delta > 0 {
            headline = "Score up \(Int(delta.rounded())) in \(days) days"
        } else {
            headline = "\(days) days of tracking"
        }
        subline = "\(scanCount) scans · monthly check-ins"
    }
}

struct ShareCardView: View {
    let content: ShareCardContent

    var body: some View {
        ZStack {
            Theme.ink
            Circle().fill(Theme.champagne.opacity(0.18)).frame(width: 320).blur(radius: 90).offset(x: 120, y: -190)
            Circle().fill(Theme.bronze.opacity(0.14)).frame(width: 260).blur(radius: 90).offset(x: -140, y: 220)
            Grain().opacity(0.6)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "crown.fill").font(.system(size: 13)).foregroundStyle(Theme.goldGradient)
                    Text("CROWN").font(.system(size: 12, weight: .semibold)).tracking(4)
                    Spacer()
                    Text(Date().formatted(.dateTime.month(.abbreviated).year())).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.tertiary)
                }
                Spacer()
                StaticDial(score: Double(content.score))
                    .frame(width: 128, height: 128)
                    .padding(.bottom, 26)
                Text(content.headline)
                    .font(Typo.display(36))
                    .foregroundStyle(Theme.ivory)
                    .fixedSize(horizontal: false, vertical: true)
                Text(content.subline)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)
                Spacer()
                Rectangle().fill(Theme.stroke).frame(height: 1).padding(.bottom, 16)
                HStack(spacing: 0) {
                    stat("\(content.score)", "Score")
                    stat(content.stage.roman, "Stage")
                    stat("\(content.scanCount)", content.scanCount == 1 ? "Scan" : "Scans")
                }
            }
            .padding(28)
        }
        .foregroundStyle(Theme.ivory)
        .frame(width: 360, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Theme.edgeGradient))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(Typo.numeral(26, weight: .regular))
            Eyebrow(label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Non-animated dial so it renders correctly into an image.
struct StaticDial: View {
    let score: Double
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<60, id: \.self) { i in
                    Capsule()
                        .fill(Double(i) / 60 < score / 100 ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.1)))
                        .frame(width: 2, height: size * 0.07)
                        .offset(y: -size * 0.44)
                        .rotationEffect(.degrees(Double(i) * 6))
                }
                Text("\(Int(score.rounded()))").font(Typo.numeral(size * 0.34))
            }
            .frame(width: size, height: size)
        }
    }
}

struct ShareCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var scans: [Scan]
    @State private var rendered: UIImage?
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if scans.isEmpty {
                    ContentUnavailableView("Nothing to share yet", systemImage: "square.and.arrow.up",
                                           description: Text("Complete a scan to create your progress card."))
                } else {
                    let content = ShareCardContent(scans: scans)
                    ShareCardView(content: content)
                        .shadow(color: Theme.gold.opacity(0.18), radius: 30, y: 10)
                        .scaleEffect(appeared ? 1 : 0.94)
                        .opacity(appeared ? 1 : 0)
                    Text("No photos are included, only your score and progress.")
                        .font(Typo.caption).foregroundStyle(Theme.tertiary)
                    if let rendered {
                        ShareLink(item: Image(uiImage: rendered), preview: SharePreview(content.headline, image: Image(uiImage: rendered))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
                guard !scans.isEmpty else { return }
                let renderer = ImageRenderer(content: ShareCardView(content: ShareCardContent(scans: scans)).environment(\.colorScheme, .dark))
                renderer.scale = 3
                rendered = renderer.uiImage
            }
        }
    }
}
