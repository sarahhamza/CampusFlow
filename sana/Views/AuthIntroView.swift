//
//  AuthIntroView.swift
//  sana
//
//  Écran d'introduction : GIF d'authentification affiché 5 secondes,
//  puis première page de connexion. Un appui permet de passer.
//

import SwiftUI

struct AuthIntroView: View {

    private let duration: Double = 5

    let onFinish: () -> Void

    @State private var appeared = false
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            AuthBackground()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    // Visible seulement si le GIF est introuvable dans le bundle.
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(.white)

                    AnimatedGIFView(name: "auth_intro")
                }
                .frame(width: 280, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .overlay(
                    RoundedRectangle(cornerRadius: 40)
                        .stroke(.white.opacity(0.35), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 6) {
                    Text("CampusFlow")
                        .font(.largeTitle.bold())

                    Text(tr("intro_secure"))
                        .font(.subheadline)
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                Spacer()

                VStack(spacing: 10) {
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .frame(width: 200, height: 5)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(.white)
                                    .frame(width: geo.size.width * progress)
                            }
                        }

                    Text(tr("tap_to_skip"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                appeared = true
            }

            withAnimation(.linear(duration: duration)) {
                progress = 1
            }

            // Si la vue disparaît avant la fin, le sleep est annulé : on ne continue pas.
            guard (try? await Task.sleep(for: .seconds(duration))) != nil
            else { return }

            onFinish()
        }
    }
}
