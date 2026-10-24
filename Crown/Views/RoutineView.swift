import Charts
import SwiftData
import SwiftUI

struct RoutinePreset: Identifiable {
    let name: String
    let symbol: String
    let intervalDays: Int
    var id: String { name }

    static let all = [
        RoutinePreset(name: "Minoxidil", symbol: "drop.fill", intervalDays: 1),
        RoutinePreset(name: "Finasteride", symbol: "pills.fill", intervalDays: 1),
        RoutinePreset(name: "Ketoconazole shampoo", symbol: "bubbles.and.sparkles.fill", intervalDays: 1),
        RoutinePreset(name: "Dermaroller", symbol: "circle.grid.cross.fill", intervalDays: 7),
        RoutinePreset(name: "Scalp massage", symbol: "hand.raised.fill", intervalDays: 1),
        RoutinePreset(name: "Hair vitamins", symbol: "capsule.fill", intervalDays: 1),
    ]
}

struct RoutineView: View {
    @Query(sort: \RoutineItem.sortOrder) private var items: [RoutineItem]
    @State private var showAdd = false
    @State private var shown = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow("Consistency wins")
                                Text("Routine").font(Typo.display(38))
                            }
                            Spacer()
                            if !items.isEmpty { IconButton(symbol: "plus", label: "Add routine step") { showAdd = true } }
                        }
                        .padding(.top, 12)
                        .reveal(shown)

                        VStack(alignment: .leading, spacing: 16) {
                            if items.isEmpty {
                                empty
                            } else {
                                StreakHero(items: items).reveal(shown, index: 1)
                                VStack(alignment: .leading, spacing: 12) {
                                    Eyebrow("Today")
                                    ForEach(items) { RoutineCheckRow(item: $0) }
                                }
                                .card()
                                .reveal(shown, index: 2)
                            }
                            ShedTracker().reveal(shown, index: 3)
                            Text("Crown records the routine you and your doctor chose. It doesn't recommend products or doses.")
                                .font(Typo.caption).foregroundStyle(Theme.tertiary).padding(.horizontal, 4)
                        }
                        .proLocked("Routine and shed tracking")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAdd) { AddRoutineSheet() }
        }
        .onAppear { shown = true }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "checklist").font(.system(size: 30, weight: .light)).foregroundStyle(Theme.goldGradient)
            Text("Build your daily ritual.").font(Typo.title)
            Text("Add the steps you follow. Check them off each day and watch your streak and adherence line up with your scans.")
                .font(Typo.subhead).foregroundStyle(Theme.secondary).lineSpacing(2)
            Button("Add routine steps") { showAdd = true }.buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
        }
        .card()
    }
}

struct StreakHero: View {
    let items: [RoutineItem]

    var body: some View {
        let best = items.map(\.streak).max() ?? 0
        let cal = Calendar.current
        let days = (0..<28).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
        let daily = items.filter { $0.intervalDays == 1 }
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(best)").font(Typo.numeral(64)).contentTransition(.numericText())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").foregroundStyle(Theme.ember)
                        Text("day streak").font(Typo.headline)
                    }
                    Text("Best current run").font(Typo.caption).foregroundStyle(Theme.tertiary)
                }
                Spacer()
            }
            // 28-day consistency grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 14), spacing: 6) {
                ForEach(days, id: \.self) { day in
                    let done = daily.isEmpty ? 0 : Double(daily.filter { $0.isDone(on: day) }.count) / Double(daily.count)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(done > 0 ? AnyShapeStyle(Theme.goldGradient.opacity(0.25 + done * 0.75)) : AnyShapeStyle(Color.white.opacity(0.06)))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            HStack {
                Text("4 weeks ago"); Spacer(); Text("Today")
            }
            .font(Typo.micro).foregroundStyle(Theme.tertiary)
        }
        .card(padding: 20, radius: 30)
    }
}

struct RoutineCheckRow: View {
    @Environment(\.modelContext) private var context
    let item: RoutineItem
    var compact = false
    @State private var confirmDelete = false

    var body: some View {
        let done = item.isDone(on: Date())
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .font(.system(size: compact ? 13 : 16))
                .foregroundStyle(done ? Theme.ink : Theme.champagne)
                .frame(width: compact ? 34 : 42, height: compact ? 34 : 42)
                .background(done ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.champagne.opacity(0.1)),
                            in: RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(compact ? Typo.subhead.weight(.medium) : Typo.headline)
                    .strikethrough(done && compact, color: Theme.tertiary)
                    .foregroundStyle(done && compact ? Theme.tertiary : Theme.ivory)
                if !compact {
                    Text(item.intervalDays == 7 ? "Weekly · \(item.streak)-week streak" : "Daily · \(item.streak)-day streak")
                        .font(Typo.caption).foregroundStyle(Theme.tertiary)
                }
            }
            Spacer()
            Button { toggle() } label: {
                ZStack {
                    Circle().strokeBorder(done ? Color.clear : Theme.tertiary, lineWidth: 1.5)
                    if done {
                        Circle().fill(Theme.goldGradient)
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 28, height: 28)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: done)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(done ? "Mark \(item.name) not done" : "Mark \(item.name) done")
        }
        .contentShape(Rectangle())
        .contextMenu {
            if !compact { Button(role: .destructive) { confirmDelete = true } label: { Label("Remove step", systemImage: "trash") } }
        }
        .confirmationDialog("Remove \(item.name) and its history?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { context.delete(item); try? context.save() }
        }
    }

    private func toggle() {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = item.logs?.first(where: { Calendar.current.isDate($0.day, inSameDayAs: today) }) {
            context.delete(existing)
        } else {
            context.insert(RoutineLog(day: today, item: item))
            Haptics.soft()
        }
        try? context.save()
    }
}

struct ShedTracker: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShedLog.day) private var logs: [ShedLog]

    private var today: ShedLog? { logs.first { Calendar.current.isDateInToday($0.day) } }
    private var recent: [ShedLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -13, to: Calendar.current.startOfDay(for: Date()))!
        return logs.filter { $0.day >= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Shed counter")
                    Text("Hairs shed today").font(Typo.title2)
                }
                Spacer()
                if !recent.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(recent.map(\.count).reduce(0, +) / recent.count)").font(Typo.numeral(22, weight: .regular))
                        Text("14-day avg").font(Typo.micro).foregroundStyle(Theme.tertiary)
                    }
                }
            }
            HStack(spacing: 14) {
                stepButton("minus", -5)
                Text("\(today?.count ?? 0)")
                    .font(Typo.numeral(52))
                    .contentTransition(.numericText(value: Double(today?.count ?? 0)))
                    .frame(maxWidth: .infinity)
                stepButton("plus", 5)
            }
            HStack(spacing: 8) {
                ForEach([1, 10, 25], id: \.self) { n in
                    Button("+\(n)") { add(n) }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.champagne)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(Theme.champagne.opacity(0.08), in: Capsule())
                }
            }
            if recent.count > 1 {
                Chart(recent, id: \.day) { log in
                    BarMark(x: .value("Day", log.day, unit: .day), y: .value("Hairs", log.count))
                        .foregroundStyle(Calendar.current.isDateInToday(log.day) ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.champagne.opacity(0.35)))
                        .cornerRadius(3)
                }
                .chartYAxis(.hidden)
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 3)) { _ in AxisValueLabel(format: .dateTime.day()).foregroundStyle(Theme.tertiary) } }
                .frame(height: 90)
            }
            Text("Count hairs from your shower drain or brush. Look at the weekly trend rather than any single day.")
                .font(Typo.caption).foregroundStyle(Theme.tertiary)
        }
        .card()
    }

    private func stepButton(_ symbol: String, _ delta: Int) -> some View {
        Button { add(delta) } label: {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.06), in: Circle())
                .overlay(Circle().strokeBorder(Theme.edgeGradient))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(Theme.ivory)
        .accessibilityLabel(delta > 0 ? "Add 5" : "Remove 5")
    }

    private func add(_ n: Int) {
        Haptics.soft()
        withAnimation(.spring(response: 0.3)) {
            if let today {
                today.count = max(0, today.count + n)
            } else if n > 0 {
                context.insert(ShedLog(day: Date(), count: n))
            }
        }
        try? context.save()
    }
}

struct AddRoutineSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [RoutineItem]
    @State private var customName = ""
    @State private var weekly = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(intensity: 0.6)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Add to routine").font(Typo.display(30))
                        VStack(spacing: 0) {
                            ForEach(RoutinePreset.all) { preset in
                                let added = items.contains { $0.name == preset.name }
                                Button { add(preset.name, preset.symbol, preset.intervalDays) } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: preset.symbol).foregroundStyle(Theme.champagne).frame(width: 26)
                                        Text(preset.name).font(Typo.callout).foregroundStyle(Theme.ivory)
                                        Spacer()
                                        Text(preset.intervalDays == 7 ? "Weekly" : "Daily").font(Typo.caption).foregroundStyle(Theme.tertiary)
                                        Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                                            .foregroundStyle(added ? Theme.sage : Theme.champagne)
                                    }
                                    .padding(.vertical, 14)
                                }
                                .disabled(added)
                                if preset.id != RoutinePreset.all.last?.id { Divider2() }
                            }
                        }
                        .card(padding: 16)
                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow("Custom step")
                            TextField("Name, e.g. Rosemary oil", text: $customName).font(Typo.callout)
                            Divider2()
                            Toggle("Weekly instead of daily", isOn: $weekly).font(Typo.subhead).tint(Theme.champagne)
                            Button("Add custom step") {
                                add(customName.trimmingCharacters(in: .whitespaces), "sparkles", weekly ? 7 : 1)
                                customName = ""
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .opacity(customName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        }
                        .card()
                    }
                    .padding(20)
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func add(_ name: String, _ symbol: String, _ interval: Int) {
        context.insert(RoutineItem(name: name, symbol: symbol, intervalDays: interval, sortOrder: items.count))
        try? context.save()
        Haptics.success()
    }
}
