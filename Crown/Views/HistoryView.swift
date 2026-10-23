import Charts
import SwiftData
import SwiftUI

struct ProgressHubView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.startScan) private var startScan
    @EnvironmentObject private var account: Account
    @Query(sort: \Scan.date) private var scans: [Scan]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journal: [JournalEntry]
    @State private var metric: Metric = .overall
    @State private var showJournal = false
    @State private var reportURL: URL?
    @State private var buildingReport = false
    @State private var shown = false

    enum Metric: String, CaseIterable { case overall = "Overall", hairline = "Hairline", temples = "Temples", crown = "Crown" }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow("\(scans.count) scan\(scans.count == 1 ? "" : "s") recorded")
                            Text("Progress").font(Typo.display(38))
                        }
                        .padding(.top, 12)
                        .reveal(shown)

                        if scans.isEmpty {
                            empty
                        } else {
                            trend.reveal(shown, index: 1)
                            tools.reveal(shown, index: 2)
                            journalSection.reveal(shown, index: 3)
                            scanList.reveal(shown, index: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showJournal) { JournalEntrySheet() }
            .sheet(item: $reportURL) { url in ActivityView(items: [url]) }
        }
        .onAppear { shown = true }
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line").font(.system(size: 40, weight: .light)).foregroundStyle(Theme.goldGradient)
            Text("Your story starts\nwith one scan.").font(Typo.title).multilineTextAlignment(.center)
            Text("Trends, comparisons, timelapse and your doctor report all build from your check-ins.")
                .font(Typo.subhead).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
            Button("Take first scan") { startScan() }.buttonStyle(PrimaryButtonStyle()).padding(.top, 6)
        }
        .padding(.vertical, 30)
        .card()
    }

    private func value(_ scan: Scan) -> Double? {
        switch metric {
        case .overall: scan.score
        case .hairline: scan.hairlineScore
        case .temples: scan.templeScore
        case .crown: scan.crownScore
        }
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Trend")
                    Text(scans.last.flatMap(value).map { "\(Int($0.rounded()))" } ?? "–").font(Typo.numeral(44))
                }
                Spacer()
                if scans.count > 1, let a = scans.first.flatMap(value), let b = scans.last.flatMap(value) {
                    DeltaBadge(delta: b - a)
                }
            }
            HStack(spacing: 6) {
                ForEach(Metric.allCases, id: \.self) { m in
                    Button { withAnimation(.spring(response: 0.4)) { metric = m } } label: {
                        Text(m.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(metric == m ? Theme.ink : Theme.secondary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(metric == m ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.05)), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            if scans.count > 1 {
                Chart {
                    ForEach(journal) { entry in
                        RuleMark(x: .value("Date", entry.date))
                            .foregroundStyle(Theme.champagne.opacity(0.25))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .annotation(position: .top) {
                                Image(systemName: entry.journalKind.symbol).font(.system(size: 9)).foregroundStyle(Theme.champagne)
                            }
                    }
                    ForEach(scans) { scan in
                        if let v = value(scan) {
                            AreaMark(x: .value("Date", scan.date), y: .value("Score", v))
                                .foregroundStyle(LinearGradient(colors: [Theme.champagne.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.catmullRom)
                            LineMark(x: .value("Date", scan.date), y: .value("Score", v))
                                .foregroundStyle(Theme.goldGradient)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", scan.date), y: .value("Score", v))
                                .foregroundStyle(Theme.ivory).symbolSize(28)
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(values: [0, 50, 100]) { _ in AxisGridLine().foregroundStyle(Color.white.opacity(0.06)); AxisValueLabel().foregroundStyle(Theme.tertiary) } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Theme.tertiary) } }
                .frame(height: 190)
                .animation(.easeInOut(duration: 0.5), value: metric)
                .proLocked("Your trend line")
            } else {
                Text("Your trend line appears after your second check-in.")
                    .font(Typo.subhead).foregroundStyle(Theme.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 90)
            }
        }
        .card(padding: 20, radius: 30)
    }

    private var tools: some View {
        HStack(spacing: 10) {
            NavigationLink { CompareView() } label: { tool("Compare", "rectangle.split.2x1") }
            NavigationLink { TimelapseView() } label: { tool("Timelapse", "play.square.stack") }
            Button { makeReport() } label: { tool(buildingReport ? "Building…" : "Doctor report", "doc.richtext") }
                .disabled(buildingReport)
        }
        .buttonStyle(PressableStyle())
    }

    private func tool(_ title: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(Theme.goldGradient)
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ivory)
        }
        .card(padding: 16, radius: 22)
    }

    @EnvironmentObject private var store: Store
    @State private var showPaywall = false

    private func makeReport() {
        guard store.isPro else { showPaywall = true; return }
        buildingReport = true
        Task { @MainActor in
            reportURL = ReportBuilder.make(scans: scans, journal: journal, name: account.profile?.name)
            buildingReport = false
        }
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Journal")
                Spacer()
                Button { showJournal = true } label: {
                    Label("Add", systemImage: "plus").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.champagne)
            }
            if journal.isEmpty {
                Text("Log treatment starts, haircuts or stressful months. They appear as markers on your trend so you can see what moved the needle.")
                    .font(Typo.subhead).foregroundStyle(Theme.tertiary).lineSpacing(2)
            } else {
                ForEach(journal.prefix(5)) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.journalKind.symbol)
                            .font(.system(size: 12)).foregroundStyle(Theme.champagne)
                            .frame(width: 30, height: 30).background(Theme.champagne.opacity(0.1), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.text).font(Typo.subhead).foregroundStyle(Theme.ivory)
                            Text("\(entry.journalKind.title) · \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(Typo.caption).foregroundStyle(Theme.tertiary)
                        }
                        Spacer()
                    }
                    .contextMenu {
                        Button(role: .destructive) { context.delete(entry); try? context.save() } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .card()
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var scanList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("All scans").padding(.leading, 4)
            ForEach(Array(scans.reversed().enumerated()), id: \.element.id) { index, scan in
                let row = NavigationLink { ScanResultView(scan: scan) } label: { ScanRow(scan: scan) }
                    .buttonStyle(PressableStyle())
                // The most recent scan is always free; older history is Pro.
                if index == 0 { row } else { row.proLocked("Full history") }
            }
        }
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ScanRow: View {
    let scan: Scan
    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let image = PhotoStore.load(scan.frontPhoto) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.square").font(.system(size: 24)).foregroundStyle(Theme.tertiary)
                }
            }
            .frame(width: 58, height: 58)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.date.formatted(.dateTime.month(.wide).day().year())).font(Typo.title2.weight(.regular))
                HStack(spacing: 8) {
                    Text("Stage \(scan.stage.roman)")
                    if let q = scan.quality { Text("·"); Text("Quality \(Int(q))%") }
                }
                .font(Typo.caption).foregroundStyle(Theme.tertiary)
            }
            Spacer()
            ScoreRing(score: scan.score).frame(width: 44, height: 44)
        }
        .card(padding: 12, radius: 22)
    }
}

struct JournalEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var kind: JournalKind = .treatment
    @State private var date = Date()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(intensity: 0.6)
                VStack(alignment: .leading, spacing: 20) {
                    Text("What changed?").font(Typo.display(30))
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(JournalKind.allCases) { k in
                                Button { withAnimation(.spring(response: 0.3)) { kind = k } } label: {
                                    Label(k.title, systemImage: k.symbol)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(kind == k ? Theme.ink : Theme.secondary)
                                        .padding(.horizontal, 14).padding(.vertical, 9)
                                        .background(kind == k ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.05)), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    TextField("e.g. Started minoxidil 5%", text: $text, axis: .vertical)
                        .font(Typo.body)
                        .lineLimit(2...5)
                        .focused($focused)
                        .card(padding: 16, radius: 18)
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        .font(Typo.subhead)
                        .card(padding: 14, radius: 18)
                    Spacer()
                    Button("Save to journal") {
                        context.insert(JournalEntry(date: date, text: text.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind))
                        try? context.save()
                        Haptics.success()
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: !text.trimmingCharacters(in: .whitespaces).isEmpty))
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { focused = true }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Compare

struct CompareView: View {
    @Query(sort: \Scan.date) private var scans: [Scan]
    @State private var beforeID: UUID?
    @State private var afterID: UUID?
    @State private var angle: ScanAngle = .front
    @State private var split: CGFloat = 0.5
    @State private var sideBySide = false
    @State private var showMarkers = true

    private var before: Scan? { scans.first { $0.id == beforeID } ?? scans.first }
    private var after: Scan? { scans.first { $0.id == afterID } ?? scans.last }

    var body: some View {
        ZStack {
            AppBackground(intensity: 0.5)
            ScrollView {
                VStack(spacing: 16) {
                    AnglePicker(angle: $angle)
                    Group {
                        if sideBySide {
                            HStack(spacing: 8) {
                                photo(before).overlay(alignment: .bottomLeading) { badge(before) }
                                photo(after).overlay(alignment: .bottomLeading) { badge(after) }
                            }
                            .aspectRatio(3 / 2, contentMode: .fit)
                        } else {
                            slider.aspectRatio(3 / 4, contentMode: .fit)
                        }
                    }
                    HStack(spacing: 10) {
                        toggle("Side by side", isOn: $sideBySide)
                        if angle == .front { toggle("Markers", isOn: $showMarkers) }
                    }
                    HStack(spacing: 10) {
                        scanPicker("Before", selection: $beforeID, fallback: scans.first)
                        scanPicker("After", selection: $afterID, fallback: scans.last)
                    }
                    if let before, let after { comparison(before, after) }
                }
                .padding(20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .proLocked("Side-by-side compare")
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Button { withAnimation(.spring(response: 0.4)) { isOn.wrappedValue.toggle() } } label: {
            Label(title, systemImage: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? Theme.champagne : Theme.secondary)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Color.white.opacity(0.05), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.edgeGradient))
        }
        .buttonStyle(.plain)
    }

    private func comparison(_ a: Scan, _ b: Scan) -> some View {
        VStack(spacing: 12) {
            row("Overall", a.score, b.score)
            row("Hairline", a.hairlineScore, b.hairlineScore)
            row("Temples", a.templeScore, b.templeScore)
            row("Crown", a.crownScore, b.crownScore)
            if (a.quality ?? 100) < 70 || (b.quality ?? 100) < 70 {
                Label("One of these photos has low quality, so differences may be lighting rather than hair.", systemImage: "exclamationmark.triangle")
                    .font(Typo.caption).foregroundStyle(Theme.ember)
            }
        }
        .card()
    }

    private func row(_ title: String, _ a: Double?, _ b: Double?) -> some View {
        HStack {
            Text(title).font(Typo.subhead).foregroundStyle(Theme.secondary)
            Spacer()
            Text(a.map { "\(Int($0.rounded()))" } ?? "–").font(Typo.numeral(18, weight: .regular)).foregroundStyle(Theme.tertiary)
            Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(Theme.tertiary)
            Text(b.map { "\(Int($0.rounded()))" } ?? "–").font(Typo.numeral(18, weight: .regular))
            if let a, let b { DeltaBadge(delta: b - a).frame(width: 76, alignment: .trailing) } else { Spacer().frame(width: 76) }
        }
    }

    private var slider: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                photo(after)
                photo(before).mask(alignment: .leading) { Rectangle().frame(width: geo.size.width * split) }
                Rectangle().fill(Theme.ivory).frame(width: 1.5).offset(x: geo.size.width * split - 0.75)
                Circle().fill(Theme.goldGradient).frame(width: 38, height: 38)
                    .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink))
                    .shadow(radius: 8)
                    .offset(x: geo.size.width * split - 19)
            }
            .overlay(alignment: .bottomLeading) { badge(before) }
            .overlay(alignment: .bottomTrailing) { badge(after) }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.edgeGradient))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in split = min(max(v.location.x / geo.size.width, 0), 1) })
        }
    }

    private func photo(_ scan: Scan?) -> some View {
        Group {
            if let image = PhotoStore.load(scan?.photo(for: angle)) {
                Image(uiImage: image).resizable().scaledToFill()
                    .overlay { if angle == .front && showMarkers, let scan { MarkerOverlay(markers: scan.markers) } }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera").font(.system(size: 22))
                    Text("No \(angle.shortTitle.lowercased()) photo").font(Typo.caption)
                }
                .foregroundStyle(Theme.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.ink3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: sideBySide ? 20 : 0, style: .continuous))
    }

    private func badge(_ scan: Scan?) -> some View {
        Text(scan?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(12)
    }

    private func scanPicker(_ title: String, selection: Binding<UUID?>, fallback: Scan?) -> some View {
        Menu {
            ForEach(scans) { scan in
                Button(scan.date.formatted(date: .abbreviated, time: .shortened)) { selection.wrappedValue = scan.id }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(title)
                let chosen = scans.first { $0.id == selection.wrappedValue } ?? fallback
                HStack {
                    Text(chosen?.date.formatted(date: .abbreviated, time: .omitted) ?? "–").font(Typo.title2.weight(.regular)).foregroundStyle(Theme.ivory)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 11)).foregroundStyle(Theme.tertiary)
                }
            }
            .card(padding: 14, radius: 20)
        }
    }
}

struct AnglePicker: View {
    @Binding var angle: ScanAngle
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ScanAngle.allCases) { a in
                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { angle = a } } label: {
                    Text(a.shortTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(angle == a ? Theme.ink : Theme.secondary)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background { if angle == a { Capsule().fill(Theme.goldGradient).matchedGeometryEffect(id: "angle", in: ns) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.edgeGradient))
    }
}

/// Draws brow line, hairline points and the measured span on the front photo.
struct MarkerOverlay: View {
    let markers: [Double]
    var body: some View {
        GeometryReader { geo in
            if markers.count >= 7 {
                let w = geo.size.width, h = geo.size.height
                // The photo is drawn scaledToFill; assume 3:4 source to map normalized points.
                let (sx, sy, ox, oy) = fillTransform(container: geo.size, aspect: 3.0 / 4.0)
                let pt = { (x: Double, y: Double) in CGPoint(x: ox + x * sx, y: oy + y * sy) }
                let brow = markers[0]
                let mid = pt(markers[1], markers[2]), left = pt(markers[3], markers[4]), right = pt(markers[5], markers[6])
                let browL = pt(markers[3], brow), browR = pt(markers[5], brow), browM = pt(markers[1], brow)
                ZStack {
                    Path { p in p.move(to: browL); p.addLine(to: browR) }
                        .stroke(Theme.ivory.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    Path { p in
                        p.move(to: left)
                        p.addQuadCurve(to: right, control: CGPoint(x: mid.x, y: mid.y - (min(left.y, right.y) - mid.y) * 0.4))
                    }
                    .stroke(Theme.goldGradient, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    Path { p in p.move(to: browM); p.addLine(to: mid) }
                        .stroke(Theme.champagne.opacity(0.8), style: StrokeStyle(lineWidth: 1))
                    ForEach([left, mid, right], id: \.x) { point in
                        Circle().fill(Theme.champagne).frame(width: 7, height: 7)
                            .shadow(color: Theme.champagne, radius: 4)
                            .position(point)
                    }
                }
                .frame(width: w, height: h)
            }
        }
        .allowsHitTesting(false)
    }

    private func fillTransform(container: CGSize, aspect: Double) -> (Double, Double, Double, Double) {
        let cw = container.width, ch = container.height
        var iw = cw, ih = cw / aspect
        if ih < ch { ih = ch; iw = ch * aspect }
        return (iw, ih, (cw - iw) / 2, (ch - ih) / 2)
    }
}

// MARK: - Timelapse

struct TimelapseView: View {
    @Query(sort: \Scan.date) private var scans: [Scan]
    @State private var angle: ScanAngle = .front
    @State private var index = 0
    @State private var playing = false
    @State private var speed = 0.8

    private var frames: [(Date, UIImage)] {
        scans.compactMap { s in PhotoStore.load(s.photo(for: angle)).map { (s.date, $0) } }
    }

    var body: some View {
        let frames = self.frames
        ZStack {
            AppBackground(intensity: 0.5)
            VStack(spacing: 18) {
                AnglePicker(angle: $angle)
                ZStack {
                    if frames.isEmpty {
                        Text("No \(angle.shortTitle.lowercased()) photos yet").font(Typo.subhead).foregroundStyle(Theme.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.ink3)
                    } else {
                        let i = min(index, frames.count - 1)
                        Image(uiImage: frames[i].1).resizable().scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(i)
                            .transition(.opacity)
                            .overlay(alignment: .bottomLeading) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Eyebrow("Frame \(i + 1) of \(frames.count)", color: Theme.ivory.opacity(0.7))
                                    Text(frames[i].0.formatted(.dateTime.month(.wide).day().year())).font(Typo.title2)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .padding(14)
                            }
                    }
                }
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.edgeGradient))

                if frames.count > 1 {
                    Slider(value: Binding(get: { Double(min(index, frames.count - 1)) }, set: { index = Int($0.rounded()) }),
                           in: 0...Double(frames.count - 1), step: 1)
                    HStack(spacing: 12) {
                        Button { playing.toggle() } label: {
                            Label(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Menu {
                            Button("Slow") { speed = 1.4 }
                            Button("Normal") { speed = 0.8 }
                            Button("Fast") { speed = 0.4 }
                        } label: { Label("Speed", systemImage: "gauge.with.dots.needle.33percent") }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                } else if frames.count == 1 {
                    Text("Timelapse plays once you have two or more scans.").font(Typo.subhead).foregroundStyle(Theme.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .navigationTitle("Timelapse")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: angle) { _, _ in index = 0 }
        .task(id: playing) {
            while playing && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                guard playing, !frames.isEmpty else { break }
                withAnimation(.easeInOut(duration: speed * 0.6)) { index = (index + 1) % frames.count }
            }
        }
        .proLocked("Timelapse")
    }
}
