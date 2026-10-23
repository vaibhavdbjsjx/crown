import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

struct ScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Scan.date, order: .reverse) private var previousScans: [Scan]
    @StateObject private var camera = CameraModel()

    @State private var angle: ScanAngle = .front
    @State private var captured: [ScanAngle: UIImage] = [:]
    @State private var review: UIImage?
    @State private var showGhost = true
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var pickerItem: PhotosPickerItem?
    @State private var analyzing = false
    @State private var errorMessage: String?
    @State private var finishedScan: Scan?
    @State private var flash = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let finishedScan {
                ScanResultView(scan: finishedScan, isNew: true) { dismiss() }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if analyzing {
                AnalyzingView()
                    .transition(.opacity)
            } else {
                captureContent
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { camera.requestAccessAndStart(angle: angle) }
        .onDisappear { camera.stop(); countdownTask?.cancel() }
        .onChange(of: pickerItem) { _, item in loadPicked(item) }
        .alert("Couldn't analyze photo", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Retake front photo") { retakeFront() }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Capture UI

    private var captureContent: some View {
        VStack(spacing: 16) {
            header
            VStack(spacing: 6) {
                Text(angle.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(angle.instruction)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 40)
            }
            .padding(.horizontal, 24)
            .id(angle)
            .transition(.push(from: .trailing))

            viewfinder
                .padding(.horizontal, 20)

            guidanceRow
            controls
        }
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Theme.surface, in: Circle())
            }
            .accessibilityLabel("Close")
            Spacer()
            HStack(spacing: 6) {
                ForEach(ScanAngle.allCases) { a in
                    Capsule()
                        .fill(a.rawValue <= angle.rawValue ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.15)))
                        .frame(width: a == angle ? 26 : 10, height: 6)
                }
            }
            .animation(.spring(response: 0.4), value: angle)
            Spacer()
            Button { withAnimation { showGhost.toggle() } } label: {
                Image(systemName: showGhost ? "square.on.square.fill" : "square.on.square")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Theme.surface, in: Circle())
            }
            .opacity(ghostImage == nil ? 0 : 1)
            .disabled(ghostImage == nil)
            .accessibilityLabel("Show last scan as a guide")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var ghostImage: UIImage? {
        guard let last = previousScans.first else { return nil }
        return PhotoStore.load(last.photo(for: angle))
    }

    private var ready: Bool { camera.guidance.ready(for: angle) }

    private var viewfinder: some View {
        GeometryReader { geo in
            ZStack {
                if let review {
                    Image(uiImage: review).resizable().scaledToFill()
                } else if camera.authorization == .authorized && camera.isAvailable {
                    CameraPreview(session: camera.session)
                    if showGhost, let ghostImage {
                        Image(uiImage: ghostImage).resizable().scaledToFill().opacity(0.28).allowsHitTesting(false)
                    }
                    overlayShape(in: geo.size)
                } else {
                    cameraUnavailable
                }
                if let countdown {
                    Text("\(countdown)")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(radius: 12)
                        .contentTransition(.numericText(countsDown: true))
                }
                if flash { Color.white.opacity(0.85) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.stroke))
        }
        .aspectRatio(3 / 4, contentMode: .fit)
    }

    @ViewBuilder
    private func overlayShape(in size: CGSize) -> some View {
        let color = ready ? Theme.gold : Color.white.opacity(0.7)
        if angle == .crown {
            Circle()
                .strokeBorder(color, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                .frame(width: size.width * 0.62)
        } else {
            Ellipse()
                .strokeBorder(color, style: StrokeStyle(lineWidth: 2.5, dash: ready ? [] : [8, 6]))
                .frame(width: size.width * 0.62, height: size.width * 0.84)
                .offset(y: -size.height * 0.03)
                .shadow(color: ready ? Theme.gold.opacity(0.6) : .clear, radius: 10)
                .animation(.easeInOut(duration: 0.3), value: ready)
        }
    }

    private var cameraUnavailable: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill").font(.system(size: 34)).foregroundStyle(Theme.gold)
            Text(camera.authorization == .denied || camera.authorization == .restricted
                 ? "Camera access is off" : "Camera not available")
                .font(.system(.headline, design: .rounded))
            Text("You can import a photo from your library instead.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            if camera.authorization == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 200)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface)
    }

    private var guidanceRow: some View {
        VStack(spacing: 10) {
            if review == nil && camera.authorization == .authorized && camera.isAvailable {
                HStack(spacing: 8) {
                    if angle != .crown {
                        chip("Centered", camera.guidance.centered)
                        chip("Distance", camera.guidance.distance)
                        chip(angle == .front ? "Straight" : "Angle", camera.guidance.level)
                    }
                    chip("Light", camera.guidance.lighting)
                }
                Text(camera.guidance.hint)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(ready ? Theme.gold : Theme.secondary)
                    .animation(.easeInOut, value: camera.guidance.hint)
            }
        }
        .frame(minHeight: 56)
    }

    private func chip(_ title: String, _ ok: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
            Text(title)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(ok ? Theme.positive : Theme.tertiary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.surface, in: Capsule())
        .animation(.spring(response: 0.3), value: ok)
    }

    @ViewBuilder
    private var controls: some View {
        if let review {
            HStack(spacing: 12) {
                Button("Retake") { withAnimation { self.review = nil } }
                    .buttonStyle(SecondaryButtonStyle())
                Button(angle == .crown ? "Use photo & analyze" : "Use photo") { accept(review) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
        } else {
            HStack {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 20))
                        Text("Import").font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 70)
                }
                Spacer()
                Button(action: shutter) {
                    ZStack {
                        Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 4).frame(width: 78, height: 78)
                        Circle()
                            .fill(ready ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.85)))
                            .frame(width: 62, height: 62)
                        if angle == .crown {
                            Image(systemName: "timer").font(.system(size: 22, weight: .bold)).foregroundStyle(.black)
                        }
                    }
                    .scaleEffect(ready ? 1.04 : 1)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: ready)
                }
                .disabled(!(camera.authorization == .authorized && camera.isAvailable) || countdown != nil)
                .accessibilityLabel(angle == .crown ? "Start 5 second timer" : "Take photo")
                Spacer()
                Button(action: skip) {
                    VStack(spacing: 4) {
                        Image(systemName: "forward.fill").font(.system(size: 20))
                        Text("Skip").font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 70)
                }
                .opacity(angle == .front ? 0 : 1)
                .disabled(angle == .front)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Actions

    private func shutter() {
        if angle == .crown {
            countdownTask = Task { @MainActor in
                for n in stride(from: 5, through: 1, by: -1) {
                    withAnimation { countdown = n }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { return }
                }
                countdown = nil
                takePhoto()
            }
        } else {
            takePhoto()
        }
    }

    private func takePhoto() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation(.easeIn(duration: 0.25)) { flash = false } }
        camera.capture { image in
            guard let image else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.4)) { review = image }
        }
    }

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                await MainActor.run { withAnimation { review = image.normalized() } }
            }
            await MainActor.run { pickerItem = nil }
        }
    }

    private func accept(_ image: UIImage) {
        captured[angle] = image
        review = nil
        advance()
    }

    private func skip() {
        advance()
    }

    private func advance() {
        if let next = ScanAngle(rawValue: angle.rawValue + 1) {
            withAnimation(.spring(response: 0.45)) { angle = next }
            camera.switchTo(angle: next)
        } else {
            finish()
        }
    }

    private func retakeFront() {
        captured = [:]
        withAnimation { angle = .front; analyzing = false }
        camera.switchTo(angle: .front)
    }

    private func finish() {
        camera.stop()
        withAnimation { analyzing = true }
        Task { @MainActor in
            let started = Date()
            let result = await HairAnalyzer.analyze(front: captured[.front], crown: captured[.crown])
            // Keep the analysis screen up long enough to read as deliberate.
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < 1.6 { try? await Task.sleep(nanoseconds: UInt64((1.6 - elapsed) * 1_000_000_000)) }
            guard result.faceFound, result.hairlineRatio != nil else {
                analyzing = false
                errorMessage = "We couldn't find your face and hairline clearly. Retake the front photo in even light with your hair pulled back."
                return
            }
            let scan = Scan()
            scan.hairlineRatio = result.hairlineRatio
            scan.templeRatio = result.templeRatio
            scan.crownCoverage = result.crownCoverage
            for (a, image) in captured { scan.setPhoto(PhotoStore.save(image), for: a) }
            context.insert(scan)
            try? context.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.6)) {
                analyzing = false
                finishedScan = scan
            }
        }
    }
}

struct AnalyzingView: View {
    @State private var rotate = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.07), lineWidth: 10).frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(Theme.goldGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                Image(systemName: "crown.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Theme.goldGradient)
                    .scaleEffect(pulse ? 1.08 : 0.94)
            }
            VStack(spacing: 8) {
                Text("Analyzing on your iPhone")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Mapping hairline, temples and crown.\nYour photos never leave this device.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { rotate = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true }
        }
    }
}
