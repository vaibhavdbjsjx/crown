import Foundation
import SwiftData

@Model
final class Scan {
    var id: UUID = UUID()
    var date: Date = Date()
    var frontPhoto: String?
    var leftPhoto: String?
    var rightPhoto: String?
    var crownPhoto: String?
    /// Forehead height (brow to hairline) divided by brow-to-chin height.
    var hairlineRatio: Double?
    /// Temple hairline height relative to the midline hairline height.
    var templeRatio: Double?
    /// Share of the crown area covered by hair, 0...1.
    var crownCoverage: Double?
    /// Photo quality 0–100 (light, sharpness, head angle). Low values make comparisons unreliable.
    var quality: Double?
    /// Normalized top-left image coordinates for the front photo overlay:
    /// [browY, midX, midHairY, leftX, leftHairY, rightX, rightHairY, chinY]
    var markers: [Double] = []
    var note: String = ""

    init(date: Date = Date()) {
        self.date = date
    }

    var hairlineScore: Double? { hairlineRatio.map { Scoring.hairline($0) } }
    var templeScore: Double? { templeRatio.map { Scoring.temple($0) } }
    var crownScore: Double? { crownCoverage.map { Scoring.crown($0) } }

    var score: Double {
        let parts = [hairlineScore, templeScore, crownScore].compactMap { $0 }
        guard !parts.isEmpty else { return 0 }
        return parts.reduce(0, +) / Double(parts.count)
    }

    var stage: Int { Scoring.stage(score: score, crownScore: crownScore) }

    func photo(for angle: ScanAngle) -> String? {
        switch angle {
        case .front: frontPhoto
        case .left: leftPhoto
        case .right: rightPhoto
        case .crown: crownPhoto
        }
    }

    func setPhoto(_ name: String?, for angle: ScanAngle) {
        switch angle {
        case .front: frontPhoto = name
        case .left: leftPhoto = name
        case .right: rightPhoto = name
        case .crown: crownPhoto = name
        }
    }

    var allPhotos: [String] { [frontPhoto, leftPhoto, rightPhoto, crownPhoto].compactMap { $0 } }
}

@Model
final class JournalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String = ""
    var kind: String = JournalKind.treatment.rawValue

    init(date: Date, text: String, kind: JournalKind) {
        self.date = date
        self.text = text
        self.kind = kind.rawValue
    }

    var journalKind: JournalKind { JournalKind(rawValue: kind) ?? .other }
}

enum JournalKind: String, CaseIterable, Identifiable {
    case treatment, haircut, lifestyle, health, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .treatment: "Treatment"
        case .haircut: "Haircut"
        case .lifestyle: "Lifestyle"
        case .health: "Health"
        case .other: "Note"
        }
    }
    var symbol: String {
        switch self {
        case .treatment: "cross.vial.fill"
        case .haircut: "scissors"
        case .lifestyle: "leaf.fill"
        case .health: "heart.fill"
        case .other: "text.quote"
        }
    }
}

@Model
final class ShedLog {
    var day: Date = Date()
    var count: Int = 0

    init(day: Date, count: Int) {
        self.day = Calendar.current.startOfDay(for: day)
        self.count = count
    }
}

@Model
final class RoutineItem {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "drop.fill"
    /// 1 = daily, 7 = weekly.
    var intervalDays: Int = 1
    var createdAt: Date = Date()
    var sortOrder: Int = 0
    @Relationship(deleteRule: .cascade, inverse: \RoutineLog.item) var logs: [RoutineLog]? = []

    init(name: String, symbol: String, intervalDays: Int, sortOrder: Int) {
        self.name = name
        self.symbol = symbol
        self.intervalDays = intervalDays
        self.sortOrder = sortOrder
    }

    var loggedDays: Set<Date> { Set((logs ?? []).map { Calendar.current.startOfDay(for: $0.day) }) }

    func isDone(on day: Date) -> Bool {
        let cal = Calendar.current
        if intervalDays == 7 {
            return loggedDays.contains { cal.isDate($0, equalTo: day, toGranularity: .weekOfYear) }
        }
        return loggedDays.contains(cal.startOfDay(for: day))
    }

    /// Consecutive days (or weeks for weekly items) completed, counting back from today.
    /// An unfinished current period doesn't break the streak.
    var streak: Int {
        let cal = Calendar.current
        let unit: Calendar.Component = intervalDays == 7 ? .weekOfYear : .day
        var cursor = Date()
        if !isDone(on: cursor) { cursor = cal.date(byAdding: unit, value: -1, to: cursor)! }
        var count = 0
        while isDone(on: cursor) {
            count += 1
            cursor = cal.date(byAdding: unit, value: -1, to: cursor)!
        }
        return count
    }
}

@Model
final class RoutineLog {
    var day: Date = Date()
    var item: RoutineItem?

    init(day: Date, item: RoutineItem) {
        self.day = Calendar.current.startOfDay(for: day)
        self.item = item
    }
}

enum ScanAngle: Int, CaseIterable, Identifiable {
    case front, left, right, crown
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .front: "Hairline"
        case .left: "Left temple"
        case .right: "Right temple"
        case .crown: "Crown"
        }
    }

    var shortTitle: String {
        switch self {
        case .front: "Front"
        case .left: "Left"
        case .right: "Right"
        case .crown: "Crown"
        }
    }

    var instruction: String {
        switch self {
        case .front: "Pull hair back, look straight ahead and fit your face inside the outline."
        case .left: "Turn your head to the right so your left temple faces the camera."
        case .right: "Turn your head to the left so your right temple faces the camera."
        case .crown: "Hold your iPhone above your head, screen up. It captures automatically after the countdown."
        }
    }

    var usesFrontCamera: Bool { self != .crown }
}

/// Converts raw measurements into 0–100 scores and a Norwood-style stage.
/// These are visual estimates for tracking change over time, not a clinical grading.
enum Scoring {
    static func clamp(_ v: Double) -> Double { min(max(v, 0), 100) }
    static func hairline(_ ratio: Double) -> Double { clamp((1 - (ratio - 0.5) / 0.42) * 100) }
    static func temple(_ ratio: Double) -> Double { clamp((1 - (ratio - 1.06) / 0.42) * 100) }
    static func crown(_ coverage: Double) -> Double { clamp((coverage - 0.4) / 0.55 * 100) }

    static func stage(score: Double, crownScore: Double?) -> Int {
        var stage: Int
        switch score {
        case 88...: stage = 1
        case 76..<88: stage = 2
        case 64..<76: stage = 3
        case 52..<64: stage = 4
        case 40..<52: stage = 5
        case 28..<40: stage = 6
        default: stage = 7
        }
        if let crownScore, crownScore < 50, stage < 3 { stage = 3 }
        return stage
    }

    static func stageSummary(_ stage: Int) -> String {
        switch stage {
        case 1: "Full hairline, no visible recession"
        case 2: "Slight recession at the temples"
        case 3: "Noticeable temple recession"
        case 4: "Recession with thinning on top"
        case 5: "Recession and crown thinning meeting"
        case 6: "Wide thinning across the top"
        default: "Extensive thinning"
        }
    }
}
