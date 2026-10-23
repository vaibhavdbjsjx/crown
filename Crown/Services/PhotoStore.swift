import UIKit

/// Stores progress photos in the app's private Application Support folder.
/// Photos are excluded from iCloud backup and never uploaded anywhere.
enum PhotoStore {
    private static let cache = NSCache<NSString, UIImage>()

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var dir = base.appendingPathComponent("Scans", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? dir.setResourceValues(values)
        }
        return dir
    }

    static func save(_ image: UIImage) -> String? {
        let name = UUID().uuidString + ".jpg"
        guard let data = image.jpegData(compressionQuality: 0.88) else { return nil }
        do {
            try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
            cache.setObject(image, forKey: name as NSString)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: directory.appendingPathComponent(name).path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func delete(_ names: [String]) {
        for name in names {
            cache.removeObject(forKey: name as NSString)
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    static func deleteAll() {
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
    }
}

extension UIImage {
    /// Returns an upright copy no larger than `maxDimension` on its longest side.
    func normalized(maxDimension: CGFloat = 1600) -> UIImage {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
