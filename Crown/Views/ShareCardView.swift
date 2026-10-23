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
            LinearGradient(colors: [Color(red: 0.1, green: 0.09, blue: 0.12), Color(red: 0.02, green: 0.02, blue: 0.03)],
                           startPoint: .top, endPoint: .bottom)
            Circle().fill(Theme.gold.opacity(0.14)).blur(radius: 80).frame(width: 300).offset(x: 110, y: -170)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill").foregroundStyle(Theme.goldGradient)
                    Text("Crown").font(.system(size: 20, weight: .bold, design: .rounded))
                }
                Spacer()
                Text(content.headline)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.goldGradient)
                    .fixedSize(horizontal: false, vertical: true)
                Text(content.subline)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)
                Spacer()
                HStack(spacing: 28) {
                    stat("\(content.score)", "Crown score")
                    stat("\(content.stage)", "Stage")
                    stat("\(content.scanCount)", content.scanCount == 1 ? "Scan" : "Scans")
                }
                Text("Tracked privately with Crown")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.top, 22)
            }
            .padding(30)
        }
        .foregroundStyle(.white)
        .frame(width: 360, height: 450)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 12, design: .rounded)).foregroundStyle(Theme.secondary)
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
                    Text("No photos are included, only your score and streak.")
                        .font(.system(size: 13, design: .rounded)).foregroundStyle(Theme.tertiary)
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
            .background(Theme.background.ignoresSafeArea())
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
