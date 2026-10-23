import AVFoundation
import UIKit
import Vision

/// Live alignment checks that keep photos consistent between check-ins.
struct Guidance: Equatable {
    var faceFound = false
    var centered = false
    var distance = false
    var level = false
    var lighting = false
    var hint = "Looking for your face"

    func ready(for angle: ScanAngle) -> Bool {
        angle == .crown ? lighting : (faceFound && centered && distance && level && lighting)
    }
}

final class CameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var guidance = Guidance()
    @Published var authorization = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var isAvailable = true

    var angle: ScanAngle = .front
    private let sessionQueue = DispatchQueue(label: "crown.camera.session")
    private let videoQueue = DispatchQueue(label: "crown.camera.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var frameCounter = 0
    private var photoCompletion: ((UIImage?) -> Void)?
    private var configured = false

    func requestAccessAndStart(angle: ScanAngle) {
        self.angle = angle
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
            startSession(angle: angle)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.authorization = granted ? .authorized : .denied
                    if granted { self.startSession(angle: angle) }
                }
            }
        default:
            authorization = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    func switchTo(angle: ScanAngle) {
        self.angle = angle
        guidance = Guidance(hint: angle == .crown ? "Checking light" : "Looking for your face")
        guard authorization == .authorized else { return }
        startSession(angle: angle)
    }

    private func startSession(angle: ScanAngle) {
        sessionQueue.async {
            let position: AVCaptureDevice.Position = angle.usesFrontCamera ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                DispatchQueue.main.async { self.isAvailable = false }
                return
            }
            self.session.beginConfiguration()
            if !self.configured {
                self.session.sessionPreset = .photo
                if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }
                self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                if self.session.canAddOutput(self.videoOutput) { self.session.addOutput(self.videoOutput) }
                self.configured = true
            }
            if self.currentInput?.device.position != position {
                if let current = self.currentInput { self.session.removeInput(current) }
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentInput = input
                }
            }
            for output in [self.videoOutput as AVCaptureOutput, self.photoOutput] {
                if let connection = output.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = position == .front
                    }
                }
            }
            self.session.commitConfiguration()
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.isAvailable = true }
        }
    }

    func stop() {
        sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async {
            guard self.session.isRunning else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.photoCompletion = completion
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .balanced
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))?.normalized()
        DispatchQueue.main.async {
            self.photoCompletion?(image)
            self.photoCompletion = nil
        }
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % 5 == 0, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let brightness = Self.averageLuma(buffer)
        var g = Guidance()
        g.lighting = brightness > 0.28
        let angle = self.angle

        if angle == .crown {
            g.hint = g.lighting ? "Light looks good" : "Find brighter, even light"
        } else {
            let request = VNDetectFaceRectanglesRequest()
            try? VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up).perform([request])
            if let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) {
                let box = face.boundingBox
                let yaw = abs(face.yaw?.doubleValue ?? 0)
                let roll = abs(face.roll?.doubleValue ?? 0)
                g.faceFound = true
                g.centered = abs(box.midX - 0.5) < 0.1 && abs((1 - box.midY) - 0.47) < 0.12
                if angle == .front {
                    g.distance = (0.42...0.66).contains(box.width)
                    g.level = yaw < 0.3 && roll < 0.18
                } else {
                    g.distance = (0.3...0.62).contains(box.width)
                    g.level = yaw > 0.45 && roll < 0.3
                }
                if !g.centered { g.hint = "Center your face in the outline" }
                else if !g.distance { g.hint = box.width < 0.42 ? "Move a little closer" : "Move a little further away" }
                else if !g.level { g.hint = angle == .front ? "Face the camera straight on" : "Turn your head further to the side" }
                else if !g.lighting { g.hint = "Find brighter, even light" }
                else { g.hint = "Hold still" }
            } else {
                g.hint = angle == .front ? "Looking for your face" : "Turn slowly until your face is detected"
            }
        }
        DispatchQueue.main.async { if self.guidance != g { self.guidance = g } }
    }

    private static func averageLuma(_ buffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return 0 }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        var sum = 0, count = 0
        for y in Swift.stride(from: 0, to: height, by: 16) {
            for x in Swift.stride(from: 0, to: width, by: 16) {
                sum += Int(ptr[y * stride + x]); count += 1
            }
        }
        return count == 0 ? 0 : Double(sum) / Double(count) / 255
    }
}
