import AuthenticationServices
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @EnvironmentObject private var account: Account
    @State private var page = 0
    @State private var shown = false

    private struct Page { let eyebrow: String; let title: String; let body: String }
    private let pages = [
        Page(eyebrow: "Hairline tracking", title: "Your hairline,\nmeasured.", body: "Guided photos and on-device analysis turn mirror worry into numbers you can trust month after month."),
        Page(eyebrow: "Consistency engine", title: "Same angle.\nEvery month.", body: "Live checks for distance, angle and light, plus your last scan as a ghost guide, make every photo truly comparable."),
        Page(eyebrow: "Private by design", title: "Your photos\nnever leave.", body: "Analysis runs on your iPhone. No uploads, no cloud copies, no ads. Lock it with Face ID if you like."),
    ]

    var body: some View {
        ZStack {
            AppBackground(intensity: 1.2)
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 7) {
                        Image(systemName: "crown.fill").font(.system(size: 14)).foregroundStyle(Theme.goldGradient)
                        Text("CROWN").font(.system(size: 13, weight: .semibold)).tracking(4)
                    }
                    Spacer()
                    if page < pages.count {
                        Button("Skip") { withAnimation(.spring(response: 0.5)) { page = pages.count } }
                            .font(Typo.subhead).foregroundStyle(Theme.tertiary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i], index: i).tag(i)
                    }
                    SignInPage(onDone: onFinish).tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: page)

                if page < pages.count {
                    VStack(spacing: 22) {
                        HStack(spacing: 6) {
                            ForEach(0...pages.count, id: \.self) { i in
                                Capsule()
                                    .fill(i == page ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.15)))
                                    .frame(width: i == page ? 28 : 6, height: 6)
                            }
                        }
                        Button("Continue") { withAnimation(.spring(response: 0.5)) { page += 1 } }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
                    .transition(.opacity)
                }
            }
        }
        .onAppear { shown = true }
    }

    private func pageView(_ p: Page, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 10)
            Group {
                switch index {
                case 0: ScanIllustration()
                case 1: GhostIllustration()
                default: VaultIllustration()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            Spacer(minLength: 10)
            Eyebrow(p.eyebrow, color: Theme.champagne)
                .reveal(shown && page == index, index: 0)
            Text(p.title)
                .font(Typo.display(44))
                .lineSpacing(-4)
                .foregroundStyle(Theme.ivory)
                .padding(.top, 12)
                .reveal(shown && page == index, index: 1)
            Text(p.body)
                .font(Typo.callout)
                .foregroundStyle(Theme.secondary)
                .lineSpacing(3)
                .padding(.top, 14)
                .reveal(shown && page == index, index: 2)
            Spacer(minLength: 24)
        }
        .padding(.horizontal, 28)
    }
}

struct SignInPage: View {
    let onDone: () -> Void
    @EnvironmentObject private var account: Account
    @State private var showPrivacy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.goldGradient)
                .shadow(color: Theme.champagne.opacity(0.5), radius: 24)
            Text("Make it\nyours.")
                .font(Typo.display(44))
                .foregroundStyle(Theme.ivory)
                .padding(.top, 22)
            Text("Sign in to personalise Crown and put your name on progress reports. Your photos still stay only on this iPhone.")
                .font(Typo.callout)
                .foregroundStyle(Theme.secondary)
                .lineSpacing(3)
                .padding(.top, 14)
            Spacer()
            SignInButtons { onDone() }
            Button("Not now") { onDone() }
                .font(Typo.subhead.weight(.medium))
                .foregroundStyle(Theme.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            HStack(spacing: 4) {
                Text("By continuing you agree to the")
                Link("Terms", destination: Legal.termsURL).foregroundStyle(Theme.champagne)
                Text("and")
                Button("Privacy Policy") { showPrivacy = true }.foregroundStyle(Theme.champagne)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 28)
        .sheet(isPresented: $showPrivacy) { NavigationStack { PrivacyPolicyView() } }
    }
}

/// Sign in with Apple, plus Gmail when a Google client ID is configured.
struct SignInButtons: View {
    var onSignedIn: () -> Void = {}
    @EnvironmentObject private var account: Account

    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { account.configure($0) } onCompletion: { result in
                account.handleApple(result)
                if account.isSignedIn { onSignedIn() }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(Capsule())

            if account.gmailAvailable {
                Button {
                    Task {
                        await account.signInWithGmail()
                        if account.isSignedIn { onSignedIn() }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if account.busy {
                            ProgressView().tint(Theme.ivory)
                        } else {
                            Image(systemName: "envelope.fill").font(.system(size: 15))
                            Text("Continue with Gmail")
                        }
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(account.busy)
            }
            if let error = account.errorMessage {
                Text(error).font(Typo.caption).foregroundStyle(Theme.ember).multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Illustrations (pure vector, animated)

struct ScanIllustration: View {
    @State private var sweep = false
    @State private var markers = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle().strokeBorder(Theme.champagne.opacity(0.08 - Double(i) * 0.02), lineWidth: 1)
                    .frame(width: 220 + CGFloat(i) * 60)
            }
            HeadOutline()
                .stroke(Theme.ivory.opacity(0.75), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(width: 150, height: 200)
            HairlineCurve()
                .trim(from: 0, to: markers ? 1 : 0)
                .stroke(Theme.goldGradient, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 150, height: 200)
            ForEach([CGPoint(x: -44, y: -62), CGPoint(x: 0, y: -74), CGPoint(x: 44, y: -62)], id: \.x) { p in
                Circle().fill(Theme.champagne).frame(width: 7, height: 7)
                    .shadow(color: Theme.champagne, radius: 6)
                    .offset(x: p.x, y: p.y)
                    .scaleEffect(markers ? 1 : 0.2)
                    .opacity(markers ? 1 : 0)
            }
            Rectangle()
                .fill(LinearGradient(colors: [.clear, Theme.champagne.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: 210, height: 1.5)
                .shadow(color: Theme.champagne, radius: 8)
                .offset(y: sweep ? 100 : -110)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { sweep = true }
            withAnimation(.easeOut(duration: 1.4).delay(0.4)) { markers = true }
        }
    }
}

struct GhostIllustration: View {
    @State private var align = false
    var body: some View {
        ZStack {
            HeadOutline()
                .stroke(Theme.ivory.opacity(0.25), style: StrokeStyle(lineWidth: 1.4, dash: [5, 5]))
                .frame(width: 150, height: 200)
                .offset(x: align ? 0 : 26, y: align ? 0 : -14)
                .rotationEffect(.degrees(align ? 0 : 8))
            HeadOutline()
                .stroke(Theme.goldGradient, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 150, height: 200)
            VStack(spacing: 8) {
                ForEach(["Centered", "Distance", "Light"], id: \.self) { label in
                    HStack(spacing: 6) {
                        Image(systemName: align ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(align ? Theme.sage : Theme.tertiary)
                        Text(label).font(Typo.micro).foregroundStyle(Theme.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .offset(x: 120, y: 30)
        }
        .onAppear { withAnimation(.spring(response: 1.6, dampingFraction: 0.75).delay(0.3).repeatForever(autoreverses: true)) { align = true } }
    }
}

struct VaultIllustration: View {
    @State private var spin = false
    var body: some View {
        ZStack {
            Circle().strokeBorder(Theme.dialGradient, lineWidth: 1.5).frame(width: 210)
                .rotationEffect(.degrees(spin ? 360 : 0))
            ForEach(0..<36, id: \.self) { i in
                Capsule().fill(Color.white.opacity(i % 3 == 0 ? 0.3 : 0.1))
                    .frame(width: 1.5, height: i % 3 == 0 ? 12 : 7)
                    .offset(y: -88)
                    .rotationEffect(.degrees(Double(i) * 10 + (spin ? 360 : 0)))
            }
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Theme.goldGradient)
                .shadow(color: Theme.champagne.opacity(0.5), radius: 24)
        }
        .onAppear { withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) { spin = true } }
    }
}

struct HeadOutline: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.42),
                   control1: CGPoint(x: r.midX + r.width * 0.42, y: r.minY), control2: CGPoint(x: r.maxX, y: r.minY + r.height * 0.18))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + r.height * 0.75), control2: CGPoint(x: r.midX + r.width * 0.28, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.42),
                   control1: CGPoint(x: r.midX - r.width * 0.28, y: r.maxY), control2: CGPoint(x: r.minX, y: r.minY + r.height * 0.75))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.minY + r.height * 0.18), control2: CGPoint(x: r.midX - r.width * 0.42, y: r.minY))
        return p
    }
}

struct HairlineCurve: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.26))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.13),
                   control1: CGPoint(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.14), control2: CGPoint(x: r.midX - r.width * 0.2, y: r.minY + r.height * 0.13))
        p.addCurve(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.minY + r.height * 0.26),
                   control1: CGPoint(x: r.midX + r.width * 0.2, y: r.minY + r.height * 0.13), control2: CGPoint(x: r.maxX - r.width * 0.2, y: r.minY + r.height * 0.14))
        return p
    }
}
