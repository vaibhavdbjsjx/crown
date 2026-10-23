import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \Scan.date, order: .reverse) private var scans: [Scan]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if scans.isEmpty {
                        ContentUnavailableView("No scans yet", systemImage: "chart.line.uptrend.xyaxis",
                                               description: Text("Your scans, comparisons and timelapse appear here after your first scan on the Today tab."))
                            .padding(.top, 80)
                    } else {
                        if scans.count >= 2 {
                            TrendCard(scans: scans.reversed()).proLocked("Your trend line")
                            HStack(spacing: 12) {
                                NavigationLink { CompareView() } label: { tile("Compare", "rectangle.split.2x1.fill") }
                                NavigationLink { TimelapseView() } label: { tile("Timelapse", "play.rectangle.fill") }
                            }
                            .buttonStyle(.plain)
                        }
                        SectionTitle(text: "All scans").padding(.top, 4)
                        VStack(spacing: 10) {
                            ForEach(Array(scans.enumerated()), id: \.element.id) { index, scan in
                                let row = NavigationLink { ScanResultView(scan: scan) } label: { ScanRow(scan: scan) }
                                    .buttonStyle(.plain)
                                // The most recent scan is always free; older history is Pro.
                                if index == 0 { row } else { row.proLocked("Full scan history") }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Progress")
        }
    }

    private func tile(_ title: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 22)).foregroundStyle(Theme.goldGradient)
            Text(title).font(.system(.headline, design: .rounded))
        }
        .card()
    }
}

struct ScanRow: View {
    let scan: Scan
    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let image = PhotoStore.load(scan.frontPhoto) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.square").font(.system(size: 26)).foregroundStyle(Theme.tertiary)
                }
            }
            .frame(width: 56, height: 56)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.date.formatted(date: .abbreviated, time: .omitted)).font(.system(.headline, design: .rounded))
                Text("Stage \(scan.stage)").font(.system(size: 13, design: .rounded)).foregroundStyle(Theme.secondary)
            }
            Spacer()
            Text("\(Int(scan.score.rounded()))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.scoreColor(scan.score))
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.tertiary)
        }
        .card(padding: 12)
    }
}

struct CompareView: View {
    @Query(sort: \Scan.date) private var scans: [Scan]
    @State private var beforeID: UUID?
    @State private var afterID: UUID?
    @State private var angle: ScanAngle = .front
    @State private var split: CGFloat = 0.5
    @State private var sideBySide = false

    private var before: Scan? { scans.first { $0.id == beforeID } ?? scans.first }
    private var after: Scan? { scans.first { $0.id == afterID } ?? scans.last }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Angle", selection: $angle) {
                    ForEach(ScanAngle.allCases) { Text($0.shortTitle).tag($0) }
                }
                .pickerStyle(.segmented)

                if sideBySide {
                    HStack(spacing: 8) {
                        photo(before).overlay(alignment: .bottomLeading) { badge(before) }
                        photo(after).overlay(alignment: .bottomLeading) { badge(after) }
                    }
                    .aspectRatio(3 / 2, contentMode: .fit)
                } else {
                    slider.aspectRatio(3 / 4, contentMode: .fit)
                }

                Toggle("Side by side", isOn: $sideBySide.animation(.spring(response: 0.4))).tint(Theme.gold)
                    .font(.system(.subheadline, design: .rounded)).card(padding: 14)

                HStack(spacing: 12) {
                    scanPicker("Before", selection: $beforeID, fallback: scans.first)
                    scanPicker("After", selection: $afterID, fallback: scans.last)
                }
                if let before, let after {
                    let delta = after.score - before.score
                    Text(abs(delta) < 2 ? "Score stable between these scans" : String(format: "Score changed %@%.0f between these scans", delta > 0 ? "+" : "", delta))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(abs(delta) < 2 || delta > 0 ? Theme.positive : Theme.warning)
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .proLocked("Side-by-side compare")
    }

    private var slider: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                photo(after)
                photo(before)
                    .mask(alignment: .leading) { Rectangle().frame(width: geo.size.width * split) }
                Rectangle().fill(.white).frame(width: 2).offset(x: geo.size.width * split - 1)
                Circle().fill(.white).frame(width: 34, height: 34)
                    .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.black))
                    .offset(x: geo.size.width * split - 17)
            }
            .overlay(alignment: .bottomLeading) { badge(before) }
            .overlay(alignment: .bottomTrailing) { badge(after) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                split = min(max(v.location.x / geo.size.width, 0), 1)
            })
        }
    }

    private func photo(_ scan: Scan?) -> some View {
        Group {
            if let image = PhotoStore.load(scan?.photo(for: angle)) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera").font(.system(size: 24))
                    Text("No \(angle.shortTitle.lowercased()) photo in this scan").font(.system(size: 12, design: .rounded))
                }
                .foregroundStyle(Theme.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.surface)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: sideBySide ? 16 : 0, style: .continuous))
    }

    private func badge(_ scan: Scan?) -> some View {
        Text(scan?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(10)
    }

    private func scanPicker(_ title: String, selection: Binding<UUID?>, fallback: Scan?) -> some View {
        Menu {
            ForEach(scans) { scan in
                Button(scan.date.formatted(date: .abbreviated, time: .shortened)) { selection.wrappedValue = scan.id }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle(text: title)
                let chosen = scans.first { $0.id == selection.wrappedValue } ?? fallback
                Text(chosen?.date.formatted(date: .abbreviated, time: .omitted) ?? "–")
                    .font(.system(.headline, design: .rounded)).foregroundStyle(.white)
            }
            .card(padding: 14)
        }
    }
}

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
        VStack(spacing: 18) {
            Picker("Angle", selection: $angle) {
                ForEach(ScanAngle.allCases) { Text($0.shortTitle).tag($0) }
            }
            .pickerStyle(.segmented)

            ZStack {
                if frames.isEmpty {
                    Text("No \(angle.shortTitle.lowercased()) photos yet").foregroundStyle(Theme.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.surface)
                } else {
                    let i = min(index, frames.count - 1)
                    Image(uiImage: frames[i].1).resizable().scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(i)
                        .transition(.opacity)
                        .overlay(alignment: .bottomLeading) {
                            Text(frames[i].0.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule()).padding(14)
                        }
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

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
                    } label: {
                        Label("Speed", systemImage: "speedometer")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Theme.background.ignoresSafeArea())
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
