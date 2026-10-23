import UIKit
import Vision

struct AnalysisResult {
    var faceFound = false
    var hairlineRatio: Double?
    var templeRatio: Double?
    var crownCoverage: Double?
}

/// On-device estimation of hairline position, temple recession and crown coverage.
/// Uses Vision face landmarks to find the brows and chin, samples forehead skin tone,
/// then walks upward until the colour changes to hair. Everything runs locally.
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
                    let measured = measureFront(bitmap: bitmap, face: face)
                    result.hairlineRatio = measured.hairline
                    result.templeRatio = measured.temple
                    skin = measured.skin
                    threshold = measured.threshold
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

    private static func measureFront(bitmap: Bitmap, face: VNFaceObservation)
        -> (hairline: Double?, temple: Double?, skin: YCC?, threshold: Double) {
        guard let landmarks = face.landmarks,
              let leftBrow = landmarks.leftEyebrow, let rightBrow = landmarks.rightEyebrow,
              let contour = landmarks.faceContour else { return (nil, nil, nil, 18) }
        let size = CGSize(width: bitmap.width, height: bitmap.height)
        func topLeft(_ region: VNFaceLandmarkRegion2D) -> [CGPoint] {
            region.pointsInImage(imageSize: size).map { CGPoint(x: $0.x, y: size.height - $0.y) }
        }
        let brows = topLeft(leftBrow) + topLeft(rightBrow)
        let chin = topLeft(contour)
        let eyes = (landmarks.leftEye.map(topLeft) ?? []) + (landmarks.rightEye.map(topLeft) ?? [])
        guard let browY = brows.map(\.y).min(), let chinY = chin.map(\.y).max() else { return (nil, nil, nil, 18) }
        let faceH = chinY - browY
        guard faceH > 40 else { return (nil, nil, nil, 18) }
        let midX = brows.map(\.x).reduce(0, +) / CGFloat(brows.count)
        let band = max(4, faceH * 0.07)

        // Forehead skin reference just above the brows.
        let patch = CGRect(x: midX - band, y: browY - faceH * 0.14, width: band * 2, height: faceH * 0.08)
        let (skin, deviation) = bitmap.stats(in: patch)
        let threshold = max(16, deviation * 3.2)

        func hairlineHeight(atX x: CGFloat) -> CGFloat {
            let start = browY - faceH * 0.06
            let limit = max(0, browY - faceH * 1.1)
            let needed = max(3, Int(faceH * 0.025))
            var run = 0
            var y = start
            while y > limit {
                let c = bitmap.average(in: CGRect(x: x - band / 2, y: y, width: band, height: 2))
                if distance(c, skin) > threshold { run += 1 } else { run = 0 }
                if run >= needed { return browY - (y + CGFloat(run)) }
                y -= 1
            }
            return browY - limit
        }

        let mid = hairlineHeight(atX: midX)
        var temple: Double?
        if let minX = eyes.map(\.x).min(), let maxX = eyes.map(\.x).max(), mid > 0 {
            let inset = (maxX - minX) * 0.04
            let left = hairlineHeight(atX: minX + inset)
            let right = hairlineHeight(atX: maxX - inset)
            temple = Double((left + right) / 2 / mid)
        }
        return (Double(mid / faceH), temple, skin, threshold)
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
