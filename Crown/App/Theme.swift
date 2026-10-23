import SwiftUI

enum Theme {
    static let background = Color(red: 0.035, green: 0.035, blue: 0.05)
    static let surface = Color.white.opacity(0.055)
    static let stroke = Color.white.opacity(0.09)
    static let gold = Color(red: 0.93, green: 0.77, blue: 0.42)
    static let goldDeep = Color(red: 0.76, green: 0.53, blue: 0.22)
    static let secondary = Color.white.opacity(0.62)
    static let tertiary = Color.white.opacity(0.4)
    static let positive = Color(red: 0.42, green: 0.86, blue: 0.62)
    static let warning = Color(red: 0.98, green: 0.62, blue: 0.36)

    static let goldGradient = LinearGradient(colors: [Color(red: 0.98, green: 0.86, blue: 0.55), goldDeep],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)

    static func scoreColor(_ score: Double) -> Color {
        switch score {
        case 75...: return positive
        case 50..<75: return gold
        default: return warning
        }
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke))
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View { modifier(CardModifier(padding: padding)) }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.goldGradient.opacity(enabled ? 1 : 0.35), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(Theme.tertiary)
    }
}

/// Animated circular gauge used for the Crown score.
struct ScoreRing: View {
    let score: Double
    var lineWidth: CGFloat = 12
    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress / 100)
                .stroke(Theme.goldGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(score.rounded()))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("score")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { progress = score } }
        .onChange(of: score) { _, new in withAnimation(.easeOut(duration: 0.8)) { progress = new } }
    }
}

enum Legal {
    static let disclaimer = "Crown provides visual estimates for personal progress tracking only. It is not a medical device and does not diagnose, treat or recommend treatment for any condition. Talk to a doctor or dermatologist about hair loss."
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
