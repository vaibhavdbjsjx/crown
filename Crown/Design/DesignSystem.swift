import SwiftUI

// MARK: - Palette  ·  "Noir & Champagne"
// Warm ink blacks, ivory text and a single champagne metal accent.
// One accent colour, used sparingly, is what keeps it premium.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    static let ink = Color(hex: 0x09090B)
    static let ink2 = Color(hex: 0x111114)
    static let ink3 = Color(hex: 0x1A1A1F)
    static let ivory = Color(hex: 0xF4EFE6)
    static let champagne = Color(hex: 0xEAD7A8)
    static let bronze = Color(hex: 0xB4854A)
    static let sage = Color(hex: 0x9CD6B0)
    static let ember = Color(hex: 0xF0A262)
    static let rose = Color(hex: 0xE7837A)

    static let background = ink
    static let surface = Color.white.opacity(0.045)
    static let stroke = Color.white.opacity(0.08)
    static let gold = champagne
    static let goldDeep = bronze
    static let primary = ivory
    static let secondary = ivory.opacity(0.62)
    static let tertiary = ivory.opacity(0.38)
    static let positive = sage
    static let warning = ember

    static let goldGradient = LinearGradient(colors: [Color(hex: 0xF6E7C1), champagne, bronze],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let edgeGradient = LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.03), .white.opacity(0.06)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let dialGradient = AngularGradient(colors: [bronze, champagne, Color(hex: 0xF6E7C1), champagne, bronze],
                                              center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))

    static func scoreColor(_ score: Double) -> Color {
        switch score {
        case 75...: sage
        case 50..<75: champagne
        default: ember
        }
    }
}

// MARK: - Typography
// Editorial pairing: New York (serif) for display and numbers, SF Pro for UI text.

enum Typo {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func numeral(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .serif).monospacedDigit()
    }
    static let largeTitle = display(36)
    static let title = display(26)
    static let title2 = display(21)
    static let headline = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 16)
    static let callout = Font.system(size: 15)
    static let subhead = Font.system(size: 14)
    static let caption = Font.system(size: 12.5)
    static let micro = Font.system(size: 11, weight: .medium)
    static let eyebrow = Font.system(size: 10.5, weight: .semibold)
    static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.tertiary
    init(_ text: String, color: Color = Theme.tertiary) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(Typo.eyebrow)
            .tracking(2.2)
            .foregroundStyle(color)
    }
}

/// Kept for older call sites.
struct SectionTitle: View {
    let text: String
    var body: some View { Eyebrow(text) }
}

// MARK: - Surfaces

struct GlassCard: ViewModifier {
    var padding: CGFloat = 20
    var radius: CGFloat = 26
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.ink2.opacity(0.72))
                    .background(.ultraThinMaterial.opacity(0.35), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.edgeGradient, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 20, radius: CGFloat = 26) -> some View { modifier(GlassCard(padding: padding, radius: radius)) }

    /// Fades and lifts content in, staggered by `index`.
    func reveal(_ shown: Bool, index: Int = 0) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .animation(.spring(response: 0.7, dampingFraction: 0.86).delay(Double(index) * 0.06), value: shown)
    }
}

/// Ink background with slow drifting champagne light and a fine film grain.
struct AppBackground: View {
    var intensity: Double = 1
    @State private var drift = false

    var body: some View {
        ZStack {
            Theme.ink
            Circle()
                .fill(Theme.champagne.opacity(0.13 * intensity))
                .frame(width: 420)
                .blur(radius: 120)
                .offset(x: drift ? 120 : -60, y: drift ? -330 : -260)
            Circle()
                .fill(Theme.bronze.opacity(0.10 * intensity))
                .frame(width: 360)
                .blur(radius: 130)
                .offset(x: drift ? -150 : -40, y: drift ? 260 : 340)
            Grain().opacity(0.5)
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = true } }
    }
}

struct Grain: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 7)
            let count = Int(size.width * size.height / 90)
            for _ in 0..<count {
                let x = rng.next() * size.width, y = rng.next() * size.height
                ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(0.035 + rng.next() * 0.03)))
            }
        }
        .allowsHitTesting(false)
        .drawingGroup()
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    @State private var shine = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                Capsule().fill(Theme.goldGradient).opacity(enabled ? 1 : 0.3)
            }
            .overlay {
                // Slow light sweep across the metal.
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.35)
                        .offset(x: shine ? geo.size.width * 1.2 : -geo.size.width * 0.5)
                        .blendMode(.overlay)
                }
                .clipShape(Capsule())
                .allowsHitTesting(false)
                .opacity(enabled ? 1 : 0)
            }
            .shadow(color: Theme.champagne.opacity(enabled ? 0.25 : 0), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.6).delay(1).repeatForever(autoreverses: false)) { shine = true }
            }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ivory)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(configuration.isPressed ? 0.09 : 0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.edgeGradient))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ivory)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.06), in: Circle())
                .overlay(Circle().strokeBorder(Theme.edgeGradient))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Score dial

/// Instrument-style dial: 72 ticks that light up to the score, serif numeral in the centre.
struct ScoreDial: View {
    let score: Double
    var size: CGFloat = 200
    var caption = "Crown score"
    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Theme.champagne.opacity(0.10), .clear], center: .center, startRadius: 0, endRadius: size * 0.55))
            ForEach(0..<72, id: \.self) { i in
                let lit = Double(i) / 72 < progress / 100
                Capsule()
                    .fill(lit ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.09)))
                    .frame(width: i % 6 == 0 ? 2.4 : 1.6, height: i % 6 == 0 ? size * 0.075 : size * 0.05)
                    .offset(y: -size * 0.44)
                    .rotationEffect(.degrees(Double(i) * 5))
            }
            Circle()
                .trim(from: 0, to: progress / 100)
                .stroke(Theme.dialGradient, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(size * 0.13)
                .opacity(0.8)
            VStack(spacing: 2) {
                Text("\(Int(progress.rounded()))")
                    .font(Typo.numeral(size * 0.32))
                    .foregroundStyle(Theme.ivory)
                    .contentTransition(.numericText(value: progress))
                Eyebrow(caption)
            }
        }
        .frame(width: size, height: size)
        .onAppear { withAnimation(.spring(response: 1.6, dampingFraction: 0.9).delay(0.15)) { progress = score } }
        .onChange(of: score) { _, new in withAnimation(.spring(response: 1.0, dampingFraction: 0.9)) { progress = new } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption) \(Int(score.rounded())) out of 100")
    }
}

/// Small ring used in compact rows.
struct ScoreRing: View {
    let score: Double
    var lineWidth: CGFloat = 4
    @State private var progress: Double = 0
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            Circle().trim(from: 0, to: progress / 100)
                .stroke(Theme.goldGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(score.rounded()))").font(Typo.numeral(15, weight: .regular)).foregroundStyle(Theme.ivory)
        }
        .onAppear { withAnimation(.easeOut(duration: 1)) { progress = score } }
    }
}

struct DeltaBadge: View {
    let delta: Double
    var body: some View {
        let stable = abs(delta) < 2
        HStack(spacing: 4) {
            Image(systemName: stable ? "equal" : (delta > 0 ? "arrow.up.right" : "arrow.down.right"))
                .font(.system(size: 10, weight: .bold))
            Text(stable ? "Stable" : String(format: "%@%.0f", delta > 0 ? "+" : "", delta))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(stable || delta > 0 ? Theme.sage : Theme.ember)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background((stable || delta > 0 ? Theme.sage : Theme.ember).opacity(0.12), in: Capsule())
    }
}

struct Divider2: View {
    var body: some View { Rectangle().fill(Theme.stroke).frame(height: 1) }
}

enum Legal {
    static let disclaimer = "Crown gives visual estimates for personal progress tracking only. It is not a medical device and does not diagnose, treat or recommend treatment for any condition. Speak with a doctor or dermatologist about hair loss."
    static let termsURL = URL(string: "https://crown-hairline.netlify.app/terms/")!
    static let privacyURL = URL(string: "https://crown-hairline.netlify.app/privacy/")!
    static let supportURL = URL(string: "https://crown-hairline.netlify.app/support/")!
    static let supportEmail = URL(string: "mailto:Support.customer19@gmail.com")!
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
