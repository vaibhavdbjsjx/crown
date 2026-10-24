import Charts
import SwiftUI
import UIKit

/// Builds a printable PDF of progress to bring to a dermatologist appointment.
@MainActor
enum ReportBuilder {
    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 48
    private static let ink = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
    private static let muted = UIColor(red: 0.42, green: 0.41, blue: 0.40, alpha: 1)
    private static let accent = UIColor(red: 0.62, green: 0.45, blue: 0.22, alpha: 1)
    private static let rule = UIColor(white: 0.86, alpha: 1)

    static func make(scans: [Scan], journal: [JournalEntry], name: String?) -> URL? {
        let sorted = scans.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Crown Progress Report.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let chart = chartImage(sorted)

        do {
            try renderer.writePDF(to: url) { ctx in
                // Page 1: summary, trend, measurements
                ctx.beginPage()
                var y = margin
                y = draw("CROWN · PROGRESS REPORT", at: y, font: .systemFont(ofSize: 9, weight: .semibold), color: accent, kern: 2)
                y = draw(name.flatMap { $0.isEmpty ? nil : $0 } ?? "Hair progress summary", at: y + 6, font: serif(28), color: ink)
                let range = "\(first.date.formatted(date: .long, time: .omitted)) – \(last.date.formatted(date: .long, time: .omitted))"
                y = draw("\(range)  ·  \(sorted.count) scans  ·  Generated \(Date().formatted(date: .abbreviated, time: .omitted))", at: y + 4, font: .systemFont(ofSize: 10), color: muted)
                y += 18; hr(y); y += 18

                let delta = last.score - first.score
                let stats: [(String, String)] = [
                    ("Latest score", "\(Int(last.score.rounded()))"),
                    ("Change", abs(delta) < 2 ? "Stable" : String(format: "%@%.0f", delta > 0 ? "+" : "", delta)),
                    ("Stage (est.)", "\(last.stage)"),
                    ("Tracking", "\(max(0, Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 0)) days"),
                ]
                let colW = (page.width - margin * 2) / CGFloat(stats.count)
                for (i, s) in stats.enumerated() {
                    let x = margin + CGFloat(i) * colW
                    drawAt(s.0.uppercased(), x: x, y: y, font: .systemFont(ofSize: 8, weight: .semibold), color: muted, kern: 1.2)
                    drawAt(s.1, x: x, y: y + 14, font: serif(26), color: ink)
                }
                y += 62

                if let chart {
                    y = draw("SCORE TREND", at: y, font: .systemFont(ofSize: 8, weight: .semibold), color: muted, kern: 1.2)
                    let h: CGFloat = 170
                    chart.draw(in: CGRect(x: margin, y: y + 6, width: page.width - margin * 2, height: h))
                    y += h + 22
                }

                y = draw("MEASUREMENTS", at: y, font: .systemFont(ofSize: 8, weight: .semibold), color: muted, kern: 1.2)
                y += 8
                let cols: [(String, CGFloat)] = [("Date", 0), ("Score", 120), ("Hairline", 180), ("Temples", 250), ("Crown", 320), ("Stage", 385), ("Photo quality", 435)]
                for c in cols { drawAt(c.0, x: margin + c.1, y: y, font: .systemFont(ofSize: 9, weight: .semibold), color: ink) }
                y += 16; hr(y); y += 6
                for scan in sorted.reversed() {
                    if y > page.height - 120 { ctx.beginPage(); y = margin }
                    func fmt(_ v: Double?) -> String { v.map { String(Int($0.rounded())) } ?? "–" }
                    let date: String = scan.date.formatted(date: .abbreviated, time: .omitted)
                    let quality: String = scan.quality.map { String(Int($0.rounded())) + "%" } ?? "–"
                    let values: [String] = [date, fmt(scan.score), fmt(scan.hairlineScore), fmt(scan.templeScore),
                                            fmt(scan.crownScore), String(scan.stage), quality]
                    for (i, v) in values.enumerated() { drawAt(v, x: margin + cols[i].1, y: y, font: .systemFont(ofSize: 9.5), color: ink) }
                    y += 17
                }

                // Page 2: photos and journal
                ctx.beginPage()
                y = margin
                y = draw("PHOTO COMPARISON", at: y, font: .systemFont(ofSize: 8, weight: .semibold), color: muted, kern: 1.2)
                y += 10
                let photoW = (page.width - margin * 2 - 16) / 2
                for angle in [ScanAngle.front, .crown] {
                    let a = PhotoStore.load(first.photo(for: angle)), b = PhotoStore.load(last.photo(for: angle))
                    guard a != nil || b != nil else { continue }
                    let h = photoW * 0.75
                    for (i, img) in [a, b].enumerated() {
                        let rect = CGRect(x: margin + CGFloat(i) * (photoW + 16), y: y, width: photoW, height: h)
                        if let img { drawFill(img, in: rect) } else { UIColor(white: 0.95, alpha: 1).setFill(); UIBezierPath(rect: rect).fill() }
                        let label = "\(angle.title) · \((i == 0 ? first : last).date.formatted(date: .abbreviated, time: .omitted))"
                        drawAt(label, x: rect.minX, y: rect.maxY + 5, font: .systemFont(ofSize: 9), color: muted)
                    }
                    y += h + 30
                }

                let notes = journal.sorted { $0.date < $1.date }
                if !notes.isEmpty {
                    y = draw("JOURNAL", at: y, font: .systemFont(ofSize: 8, weight: .semibold), color: muted, kern: 1.2)
                    y += 6
                    for entry in notes {
                        if y > page.height - 90 { ctx.beginPage(); y = margin }
                        drawAt(entry.date.formatted(date: .abbreviated, time: .omitted), x: margin, y: y, font: .systemFont(ofSize: 9.5, weight: .semibold), color: ink)
                        y = draw("\(entry.journalKind.title): \(entry.text)", at: y, x: margin + 90, font: .systemFont(ofSize: 9.5), color: ink) + 6
                    }
                }

                let footer = "Measurements are photo-based estimates recorded by the user for personal tracking. They are not a diagnosis. " +
                    "Photo quality reflects lighting, sharpness and head angle; low-quality scans are less comparable."
                _ = draw(footer, at: page.height - margin - 26, font: .systemFont(ofSize: 8), color: muted)
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: Drawing helpers

    private static func serif(_ size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .regular)
        return base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? base
    }

    @discardableResult
    private static func draw(_ text: String, at y: CGFloat, x: CGFloat? = nil, font: UIFont, color: UIColor, kern: CGFloat = 0) -> CGFloat {
        let left = x ?? margin
        let width = page.width - margin - left
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: kern]
        let rect = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                   options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        (text as NSString).draw(with: CGRect(x: left, y: y, width: width, height: rect.height),
                                options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        return y + ceil(rect.height)
    }

    private static func drawAt(_ text: String, x: CGFloat, y: CGFloat, font: UIFont, color: UIColor, kern: CGFloat = 0) {
        (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color, .kern: kern])
    }

    private static func hr(_ y: CGFloat) {
        rule.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y, width: page.width - margin * 2, height: 0.75)).fill()
    }

    private static func drawFill(_ image: UIImage, in rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: 6).addClip()
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
        ctx.restoreGState()
    }

    private static func chartImage(_ scans: [Scan]) -> UIImage? {
        guard scans.count > 1 else { return nil }
        let points = scans.map { ($0.date, $0.score) }
        let view = Chart(points, id: \.0) { p in
            AreaMark(x: .value("Date", p.0), y: .value("Score", p.1))
                .foregroundStyle(Color(accent).opacity(0.12))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("Date", p.0), y: .value("Score", p.1))
                .foregroundStyle(Color(accent))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            PointMark(x: .value("Date", p.0), y: .value("Score", p.1))
                .foregroundStyle(Color(accent))
                .symbolSize(24)
        }
        .chartYScale(domain: 0...100)
        .environment(\.colorScheme, .light)
        .frame(width: 516, height: 170)
        .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage
    }
}
