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
        RoutinePreset(name: "Anti-dandruff shampoo", symbol: "bubbles.and.sparkles.fill", intervalDays: 1),
        RoutinePreset(name: "Dermaroller", symbol: "circle.grid.cross.fill", intervalDays: 7),
        RoutinePreset(name: "Scalp massage", symbol: "hand.raised.fill", intervalDays: 1),
    ]
}

struct RoutineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RoutineItem.sortOrder) private var items: [RoutineItem]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if items.isEmpty {
                        emptyState
                    } else {
                        summary
                        SectionTitle(text: "Today")
                        VStack(spacing: 10) {
                            ForEach(items) { item in RoutineRow(item: item) }
                        }
                        Text("Crown tracks the routine you and your doctor chose. It doesn't recommend products or doses.")
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(Theme.tertiary)
                    }
                }
                .padding(20)
                .proLocked("Routine tracking with streaks")
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Routine")
            .toolbar {
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add routine item")
                    }
                }
            }
            .sheet(isPresented: $showAdd) { AddRoutineSheet(nextOrder: items.count) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "checklist")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Theme.goldGradient)
                .padding(.top, 50)
            Text("Build your routine").font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Check off each step daily and keep your streak alive. Consistency is what makes monthly scans meaningful.")
                .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
            Button("Add routine items") { showAdd = true }.buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    private var summary: some View {
        let best = items.map(\.streak).max() ?? 0
        let doneToday = items.filter { $0.isDone(on: Date()) }.count
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle(text: "Today")
                Text("\(doneToday)/\(items.count)").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("steps done").font(.system(size: 12, design: .rounded)).foregroundStyle(Theme.secondary)
            }
            .card()
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle(text: "Best streak")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(best)").font(.system(size: 30, weight: .bold, design: .rounded)).contentTransition(.numericText())
                    Image(systemName: "flame.fill").foregroundStyle(Theme.warning)
                }
                Text("in a row").font(.system(size: 12, design: .rounded)).foregroundStyle(Theme.secondary)
            }
            .card()
        }
    }
}

struct RoutineRow: View {
    @Environment(\.modelContext) private var context
    let item: RoutineItem
    @State private var confirmDelete = false

    var body: some View {
        let done = item.isDone(on: Date())
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: item.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(done ? .black : Theme.gold)
                    .frame(width: 44, height: 44)
                    .background(done ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.gold.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.system(.headline, design: .rounded))
                    Text(item.intervalDays == 7 ? "Weekly · \(item.streak) week streak" : "Daily · \(item.streak) day streak")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                Button { toggle() } label: {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 30))
                        .foregroundStyle(done ? Theme.gold : Theme.tertiary)
                        .symbolEffect(.bounce, value: done)
                }
                .accessibilityLabel(done ? "Mark \(item.name) not done" : "Mark \(item.name) done")
            }
            weekDots
        }
        .card(padding: 14)
        .contextMenu {
            Button(role: .destructive) { confirmDelete = true } label: { Label("Remove", systemImage: "trash") }
        }
        .confirmationDialog("Remove \(item.name) and its history?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { context.delete(item); try? context.save() }
        }
    }

    private var weekDots: some View {
        let cal = Calendar.current
        let days = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
        let logged = item.loggedDays
        return HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                VStack(spacing: 4) {
                    Circle()
                        .fill(logged.contains(cal.startOfDay(for: day)) ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                        .frame(width: 10, height: 10)
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 10, design: .rounded)).foregroundStyle(Theme.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func toggle() {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = item.logs?.first(where: { Calendar.current.isDate($0.day, inSameDayAs: today) }) {
            context.delete(existing)
        } else {
            context.insert(RoutineLog(day: today, item: item))
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        try? context.save()
    }
}

struct AddRoutineSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [RoutineItem]
    let nextOrder: Int
    @State private var customName = ""
    @State private var weekly = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Common steps") {
                    ForEach(RoutinePreset.all) { preset in
                        let added = items.contains { $0.name == preset.name }
                        Button {
                            add(preset.name, preset.symbol, preset.intervalDays)
                        } label: {
                            HStack {
                                Image(systemName: preset.symbol).foregroundStyle(Theme.gold).frame(width: 26)
                                Text(preset.name).foregroundStyle(.white)
                                Spacer()
                                Text(preset.intervalDays == 7 ? "Weekly" : "Daily").foregroundStyle(Theme.tertiary)
                                Image(systemName: added ? "checkmark" : "plus.circle.fill").foregroundStyle(added ? Theme.positive : Theme.gold)
                            }
                        }
                        .disabled(added)
                    }
                }
                Section("Custom step") {
                    TextField("Name, e.g. Biotin", text: $customName)
                    Toggle("Weekly instead of daily", isOn: $weekly).tint(Theme.gold)
                    Button("Add custom step") {
                        add(customName.trimmingCharacters(in: .whitespaces), "sparkles", weekly ? 7 : 1)
                        customName = ""
                    }
                    .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Add to routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func add(_ name: String, _ symbol: String, _ interval: Int) {
        context.insert(RoutineItem(name: name, symbol: symbol, intervalDays: interval, sortOrder: nextOrder + items.count))
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
