import SwiftUI

struct CampusEntrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 14)
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { visible = true }
            }
    }
}

struct CampusScreenStyle: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .fontDesign(.rounded)
            .scrollContentBackground(.hidden)
            .background {
                LinearGradient(colors: [Color(.systemGroupedBackground), Color.indigo.opacity(0.07), Color.teal.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .modifier(CampusEntrance())
            .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
    }
}

struct LoginSuccessView: View {
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var unlocked = false
    var body: some View {
        ZStack {
            AuthBackground()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 36)
                        .fill(.white.opacity(0.15))
                        .frame(width: 220, height: 260)
                        .overlay(RoundedRectangle(cornerRadius: 36).stroke(.white.opacity(0.4)))
                    VStack(spacing: 18) {
                        ForEach(0..<3) { _ in Capsule().fill(.white.opacity(0.35)).frame(width: 72, height: 4) }
                        Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 64, weight: .light))
                            .contentTransition(.symbolEffect(.replace))
                            .rotationEffect(.degrees(unlocked || reduceMotion ? 0 : -8))
                        Image(systemName: "checkmark.seal.fill").font(.title).foregroundStyle(.mint)
                            .opacity(unlocked ? 1 : 0)
                    }
                }
                Text(tr("login_success")).font(.largeTitle.bold())
                Text(tr("locker_ready")).multilineTextAlignment(.center).opacity(0.8)
                Spacer()
                Button(action: onContinue) {
                    Label(tr("continue_campus"), systemImage: "arrow.right")
                        .font(.headline).frame(maxWidth: .infinity).padding(20)
                        .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(PressableStyle())
            }.padding(32).foregroundStyle(.white)
        }
        .task {
            guard (try? await Task.sleep(for: .milliseconds(350))) != nil else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.6)) { unlocked = true }
        }
    }
}
