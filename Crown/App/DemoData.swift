#if DEBUG
import SwiftData
import SwiftUI

/// Debug-only sample data used to capture App Store screenshots. Never compiled into release builds.
enum DemoData {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var initialTab: AppTab {
        if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-tab"),
           i + 1 < ProcessInfo.processInfo.arguments.count,
           let n = Int(ProcessInfo.processInfo.arguments[i + 1]), let t = AppTab(rawValue: n) { return t }
        return .today
    }

    @MainActor
    static func seed(_ context: ModelContext) {
        guard isEnabled, (try? context.fetchCount(FetchDescriptor<Scan>())) == 0 else { return }
        UserDefaults.standard.set(true, forKey: "hasOnboarded")
        let cal = Calendar.current
        let scores: [(Double, Double, Double)] = [(64, 58, 61), (65, 60, 63), (68, 63, 66), (70, 66, 69), (73, 68, 72), (76, 71, 75)]
        for (i, s) in scores.enumerated() {
            let scan = Scan(date: cal.date(byAdding: .day, value: -30 * (scores.count - 1 - i), to: Date())!)
            scan.hairlineRatio = 0.5 + (1 - s.0 / 100) * 0.42
            scan.templeRatio = 1.06 + (1 - s.1 / 100) * 0.42
            scan.crownCoverage = 0.4 + s.2 / 100 * 0.55
            scan.quality = [82, 88, 91, 86, 93, 95][i]
            context.insert(scan)
        }
        context.insert(JournalEntry(date: cal.date(byAdding: .day, value: -140, to: Date())!, text: "Started minoxidil 5%", kind: .treatment))
        context.insert(JournalEntry(date: cal.date(byAdding: .day, value: -75, to: Date())!, text: "Shorter haircut", kind: .haircut))
        let presets = RoutinePreset.all.prefix(4)
        for (i, p) in presets.enumerated() {
            let item = RoutineItem(name: p.name, symbol: p.symbol, intervalDays: p.intervalDays, sortOrder: i)
            context.insert(item)
            for d in 0..<26 where (d + i) % 9 != 4 && !(i == 3 && d % 7 != 0) && !(d == 0 && i > 1) {
                context.insert(RoutineLog(day: cal.date(byAdding: .day, value: -d, to: Date())!, item: item))
            }
        }
        for d in 0..<14 { context.insert(ShedLog(day: cal.date(byAdding: .day, value: -d, to: Date())!, count: [62, 58, 71, 55, 49, 66, 53, 60, 47, 52, 58, 44, 50, 46][d])) }
        try? context.save()
    }
}
#endif
