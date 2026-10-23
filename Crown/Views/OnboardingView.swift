import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    @State private var animate = false

    private let pages: [(icon: String, title: String, body: String)] = [
        ("crown.fill", "Know where your hairline stands", "Crown measures your hairline, temples and crown from guided photos, so you can track change with numbers, not mirror anxiety."),
        ("viewfinder", "Same angle, every time", "A face outline, live checks for distance and light, and your last scan as a ghost guide make each monthly photo truly comparable."),
        ("lock.shield.fill", "Private by design", "Photos and analysis stay on your iPhone. No account, no uploads, no ads."),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Circle().fill(Theme.gold.opacity(0.12)).blur(radius: 90).frame(width: 320)
                .offset(x: animate ? 80 : -80, y: -220)
                .animation(.easeInOut(duration: 6).repeatForever(), value: animate)
            VStack(spacing: 24) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 26) {
                            Spacer()
                            ZStack {
                                Circle().strokeBorder(Theme.goldGradient.opacity(0.4), lineWidth: 1).frame(width: 190, height: 190)
                                    .scaleEffect(animate ? 1.06 : 0.96)
                                    .animation(.easeInOut(duration: 2.2).repeatForever(), value: animate)
                                Circle().fill(Theme.gold.opacity(0.08)).frame(width: 150, height: 150)
                                Image(systemName: pages[i].icon)
                                    .font(.system(size: 62, weight: .regular))
                                    .foregroundStyle(Theme.goldGradient)
                                    .symbolEffect(.bounce, value: page == i)
                            }
                            VStack(spacing: 12) {
                                Text(pages[i].title)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                Text(pages[i].body)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(Theme.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 28)
                            Spacer()
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule().fill(i == page ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.18)))
                            .frame(width: i == page ? 24 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.4), value: page)

                VStack(spacing: 12) {
                    Button(page == pages.count - 1 ? "Get started" : "Continue") {
                        if page < pages.count - 1 { withAnimation { page += 1 } } else { onFinish() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Text("For personal tracking only. Not a medical diagnosis.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.tertiary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .onAppear { animate = true }
    }
}
