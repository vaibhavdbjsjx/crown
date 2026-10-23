import UIKit
import Vision

struct AnalysisResult {
    var faceFound = false
    var hairlineRatio: Double?
    var templeRatio: Double?
    var crownCoverage: Double?
    var quality: Double?
    var qualityIssues: [String] = []
    /// See `Scan.markers`.
    var markers: [Double] = []
}

/// On-device estimation of hairline position, temple recession and crown coverage.
/// Vision finds brows and chin and segments the person from the background; Crown samples
/// forehead skin tone and walks upward until it meets hair or the top of the head.
/// Everything runs locally; nothing is uploaded.
enum HairAnalyzer {
    struct YCC { var y: Double; var cb: Double; var cr: Double }

    static func analyze(front: UIImage?, crown: UIImage?) async -> AnalysisResult {
        await Task.detached(priority: .userInitiated) {
            var result = AnalysisResult()
            var skin: YCC?
            var threshold = 18.0
            if let front, let bitmap = Bitmap(image: front.normalized(maxDimension: 900)) {
                if let face = largestFace(in: bitmap.cgImage) {
                    result.faceFound = true
                    let mask = PersonMask(image: bitmap.cgImage)
                    let measured = measureFront(bitmap: bitmap, face: face, mask: mask)
                    result.hairlineRatio = measured.hairline
                    result.templeRatio = measured.temple
                    result.markers = measured.markers
                    skin = measured.skin
                    threshold = measured.threshold
                    let q = quality(bitmap: bitmap, face: face)
                    result.quality = q.score
                    result.qualityIssues = q.issues
                }
            }
            if let crown, let skin, let bitmap = Bitmap(image: crown.normalized(maxDimension: 700)) {
                result.crownCoverage = crownCoverage(bitmap: bitmap, skin: skin, threshold: threshold)
            }
            return result
        }.value
    }

    // MARK: - Face

    private static func largestFace(in image: CGImage) -> VNFaceObservation? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try? handler.perform([request])
        return request.results?.max { $0.boundingBox.width < $1.boundingBox.width }
    }

    /// Person segmentation so a bare scalp against a light wall isn't mistaken for forehead.
    struct PersonMask {
        private let buffer: CVPixelBuffer?
        init(image: CGImage) {
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .balanced
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8
            try? VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
            buffer = request.results?.first?.pixelBuffer
        }
        /// nx, ny are normalized top-left coordinates. Returns true when unknown.
        func isPerson(nx: Double, ny: Double) -> Bool {
            guard let buffer else { return true }
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
            let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
            guard let base = CVPixelBufferGetBaseAddress(buffer) else { return true }
            let x = min(max(Int(nx * Double(w)), 0), w - 1), y = min(max(Int(ny * Double(h)), 0), h - 1)
            let v = base.assumingMemoryBound(to: UInt8.self)[y * CVPixelBufferGetBytesPerRow(buffer) + x]
            return v > 110
        }
    }

    private static func measureFront(bitmap: Bitmap, face: VNFaceObservation, mask: PersonMask)
        -> (hairline: Double?, temple: Double?, skin: YCC?, threshold: Double, markers: [Double]) {
        guard let landmarks = face.landmarks,
              let leftBrow = landmarks.leftEyebrow, let rightBrow = landmarks.rightEyebrow,
              let contour = landmarks.faceContour else { return (nil, nil, nil, 18, []) }
        let size = CGSize(width: bitmap.width, height: bitmap.height)
        func topLeft(_ region: VNFaceLandmarkRegion2D) -> [CGPoint] {
            region.pointsInImage(imageSize: size).map { CGPoint(x: $0.x, y: size.height - $0.y) }
        }
        let brows = topLeft(leftBrow) + topLeft(rightBrow)
        let chin = topLeft(contour)
        let eyes = (landmarks.leftEye.map(topLeft) ?? []) + (landmarks.rightEye.map(topLeft) ?? [])
        guard let browY = brows.map(\.y).min(), let chinY = chin.map(\.y).max() else { return (nil, nil, nil, 18, []) }
        let faceH = chinY - browY
        guard faceH > 40 else { return (nil, nil, nil, 18, []) }
        let midX = brows.map(\.x).reduce(0, +) / CGFloat(brows.count)
        let band = max(4, faceH * 0.07)

        // Forehead skin reference just above the brows.
        let patch = CGRect(x: midX - band, y: browY - faceH * 0.14, width: band * 2, height: faceH * 0.08)
        let (skin, deviation) = bitmap.stats(in: patch)
        let threshold = max(16, deviation * 3.2)

        /// Returns the hairline's y (top-left pixel coordinates) above column x.
        func hairlineY(atX x: CGFloat) -> CGFloat {
            let start = browY - faceH * 0.06
            let limit = max(0, browY - faceH * 1.1)
            let needed = max(3, Int(faceH * 0.025))
            var run = 0
            var y = start
            while y > limit {
                let c = bitmap.average(in: CGRect(x: x - band / 2, y: y, width: band, height: 2))
                let outside = !mask.isPerson(nx: Double(x / size.width), ny: Double(y / size.height))
                if outside || distance(c, skin) > threshold { run += 1 } else { run = 0 }
                if run >= needed { return y + CGFloat(run) }
                y -= 1
            }
            return limit
        }

        let midY = hairlineY(atX: midX)
        let mid = browY - midY
        var temple: Double?
        var markers: [Double] = []
        let w = Double(size.width), h = Double(size.height)
        if let minX = eyes.map(\.x).min(), let maxX = eyes.map(\.x).max(), mid > 0 {
            let inset = (maxX - minX) * 0.04
            let lx = minX + inset, rx = maxX - inset
            let ly = hairlineY(atX: lx), ry = hairlineY(atX: rx)
            temple = Double(((browY - ly) + (browY - ry)) / 2 / mid)
            markers = [Double(browY) / h, Double(midX) / w, Double(midY) / h,
                       Double(lx) / w, Double(ly) / h, Double(rx) / w, Double(ry) / h, Double(chinY) / h]
        }
        return (Double(mid / faceH), temple, skin, threshold, markers)
    }

    // MARK: - Quality

    /// Scores how comparable a photo is: exposure, evenness, sharpness and head angle.
    private static func quality(bitmap: Bitmap, face: VNFaceObservation) -> (score: Double, issues: [String]) {
        let w = Double(bitmap.width), h = Double(bitmap.height)
        let box = face.boundingBox
        let rect = CGRect(x: box.minX * w, y: (1 - box.maxY) * h, width: box.width * w, height: box.height * h)
        var issues: [String] = []
        var score = 100.0

        let leftHalf = bitmap.average(in: CGRect(x: rect.minX, y: rect.midY - rect.height * 0.1, width: rect.width * 0.3, height: rect.height * 0.2))
        let rightHalf = bitmap.average(in: CGRect(x: rect.maxX - rect.width * 0.3, y: rect.midY - rect.height * 0.1, width: rect.width * 0.3, height: rect.height * 0.2))
        let luma = (leftHalf.y + rightHalf.y) / 2
        if luma < 70 { score -= 30; issues.append("Too dark") } else if luma > 225 { score -= 20; issues.append("Overexposed") }
        if abs(leftHalf.y - rightHalf.y) > 45 { score -= 20; issues.append("Uneven light") }

        // Sharpness: mean absolute Laplacian across the face.
        var lap = 0.0, n = 0.0
        let step = max(2, Int(rect.width / 60))
        var y = Int(rect.minY) + step
        while y < Int(rect.maxY) - step {
            var x = Int(rect.minX) + step
            while x < Int(rect.maxX) - step {
                let c = bitmap.color(x: x, y: y).y
                let s = bitmap.color(x: x - step, y: y).y + bitmap.color(x: x + step, y: y).y
                    + bitmap.color(x: x, y: y - step).y + bitmap.color(x: x, y: y + step).y
                lap += abs(4 * c - s); n += 1
                x += step
            }
            y += step
        }
        if n > 0, lap / n < 9 { score -= 25; issues.append("Blurry") }

        let yaw = abs(face.yaw?.doubleValue ?? 0), roll = abs(face.roll?.doubleValue ?? 0)
        if yaw > 0.3 || roll > 0.2 { score -= 20; issues.append("Head tilted") }
        if box.width < 0.3 { score -= 15; issues.append("Too far away") }
        return (max(score, 5), issues)
    }

    // MARK: - Crown

    private static func crownCoverage(bitmap: Bitmap, skin: YCC, threshold: Double) -> Double {
        let cx = Double(bitmap.width) / 2, cy = Double(bitmap.height) / 2
        let r = Double(min(bitmap.width, bitmap.height)) * 0.3
        var scalp = 0, total = 0
        var y = cy - r
        while y < cy + r {
            var x = cx - r
            while x < cx + r {
                if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r {
                    total += 1
                    if distance(bitmap.color(x: Int(x), y: Int(y)), skin) < threshold * 1.15 { scalp += 1 }
                }
                x += 3
            }
            y += 3
        }
        guard total > 0 else { return 0 }
        return 1 - Double(scalp) / Double(total)
    }

    /// Luma differences are down-weighted so forehead shading doesn't read as hair.
    static func distance(_ a: YCC, _ b: YCC) -> Double {
        let dy = a.y - b.y, dcb = a.cb - b.cb, dcr = a.cr - b.cr
        return (0.35 * dy * dy + dcb * dcb + dcr * dcr).squareRoot()
    }

    // MARK: - Bitmap

    struct Bitmap {
        let cgImage: CGImage
        let width: Int
        let height: Int
        private let pixels: [UInt8]

        init?(image: UIImage) {
            guard let cg = image.cgImage else { return nil }
            let width = cg.width, height = cg.height
            self.width = width
            self.height = height
            var buffer = [UInt8](repeating: 0, count: width * height * 4)
            let ok = buffer.withUnsafeMutableBytes { ptr -> Bool in
                guard let ctx = CGContext(data: ptr.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            guard ok, let rendered = Bitmap.makeImage(buffer, width: width, height: height) else { return nil }
            pixels = buffer
            cgImage = rendered
        }

        private static func makeImage(_ buffer: [UInt8], width: Int, height: Int) -> CGImage? {
            guard let provider = CGDataProvider(data: Data(buffer) as CFData) else { return nil }
            return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                           space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                           provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }

        func color(x: Int, y: Int) -> YCC {
            let cx = min(max(x, 0), width - 1), cy = min(max(y, 0), height - 1)
            let i = (cy * width + cx) * 4
            let r = Double(pixels[i]), g = Double(pixels[i + 1]), b = Double(pixels[i + 2])
            return YCC(y: 0.299 * r + 0.587 * g + 0.114 * b,
                       cb: 128 - 0.168736 * r - 0.331264 * g + 0.5 * b,
                       cr: 128 + 0.5 * r - 0.418688 * g - 0.081312 * b)
        }

        func average(in rect: CGRect) -> YCC {
            var sum = YCC(y: 0, cb: 0, cr: 0)
            var n = 0.0
            for y in Int(rect.minY)..<max(Int(rect.minY) + 1, Int(rect.maxY)) {
                for x in Int(rect.minX)..<max(Int(rect.minX) + 1, Int(rect.maxX)) {
                    let c = color(x: x, y: y)
                    sum.y += c.y; sum.cb += c.cb; sum.cr += c.cr
                    n += 1
                }
            }
            return YCC(y: sum.y / n, cb: sum.cb / n, cr: sum.cr / n)
        }

        func stats(in rect: CGRect) -> (YCC, Double) {
            let mean = average(in: rect)
            var dev = 0.0, n = 0.0
            for y in Int(rect.minY)..<max(Int(rect.minY) + 1, Int(rect.maxY)) {
                for x in Int(rect.minX)..<max(Int(rect.minX) + 1, Int(rect.maxX)) {
                    dev += HairAnalyzer.distance(color(x: x, y: y), mean)
                    n += 1
                }
            }
            return (mean, dev / n)
        }
    }
}
