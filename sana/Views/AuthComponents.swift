//
//  AuthComponents.swift
//  sana
//
//  Composants visuels partagés par les écrans d'authentification.
//

import SwiftUI
import ImageIO

// MARK: - Fond animé

struct AuthBackground: View {

    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.26, green: 0.22, blue: 0.79),
                    Color(red: 0.49, green: 0.23, blue: 0.93)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 280, height: 280)
                .offset(x: drift ? 120 : 60, y: drift ? -260 : -300)
                .blur(radius: 30)

            Circle()
                .fill(.cyan.opacity(0.18))
                .frame(width: 240, height: 240)
                .offset(x: drift ? -140 : -90, y: drift ? 300 : 340)
                .blur(radius: 40)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 6).repeatForever(autoreverses: true)
            ) {
                drift = true
            }
        }
    }
}

// MARK: - GIF animé (ImageIO)

/// Affiche un GIF du bundle (sans librairie externe).
struct AnimatedGIFView: UIViewRepresentable {

    let name: String

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.image = Self.load(name)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {}

    static func load(_ name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }

        var frames: [UIImage] = []
        var total = 0.0

        for index in 0..<CGImageSourceGetCount(source) {
            guard let cg = CGImageSourceCreateImageAtIndex(source, index, nil)
            else { continue }

            var delay = 0.1

            if let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
                as? [CFString: Any],
               let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                delay = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                    ?? (gif[kCGImagePropertyGIFDelayTime] as? Double)
                    ?? 0.1
                if delay < 0.02 { delay = 0.1 }
            }

            total += delay
            frames.append(UIImage(cgImage: cg))
        }

        return UIImage.animatedImage(with: frames, duration: total)
    }
}

// MARK: - Effets et styles

/// Secousse horizontale (formulaire invalide).
struct Shake: GeometryEffect {

    var amount: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakes),
                y: 0
            )
        )
    }
}

struct PressableStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(
                .spring(response: 0.25, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

// MARK: - Bouton principal

struct AuthPrimaryButton: View {

    let titleKey: String
    let loading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(tr(titleKey))
                    .font(.headline)
                    .opacity(loading ? 0 : 1)

                if loading {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .shadow(color: .indigo.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(PressableStyle())
        .disabled(loading)
    }
}

// MARK: - Champ de saisie

struct AuthField<Field: Hashable>: View {

    let icon: String
    let placeholderKey: String
    @Binding var text: String
    var isSecure = false
    var error: String? = nil
    var isValid = false
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var autocap: TextInputAutocapitalization = .never
    var submitLabel: SubmitLabel = .next
    var focus: FocusState<Field?>.Binding
    let field: Field
    var onSubmit: () -> Void = {}

    @State private var reveal = false

    private var isFocused: Bool {
        focus.wrappedValue == field
    }

    private var borderColor: Color {
        if error != nil { return .red }
        return isFocused ? .indigo : .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(isFocused ? Color.indigo : Color.secondary)
                    .frame(width: 22)

                Group {
                    if isSecure && !reveal {
                        SecureField(tr(placeholderKey), text: $text)
                    } else {
                        TextField(tr(placeholderKey), text: $text)
                    }
                }
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled()
                .focused(focus, equals: field)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)

                if isSecure {
                    Button {
                        reveal.toggle()
                    } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(
                        tr(reveal ? "hide_password" : "show_password")
                    )
                } else if isValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.2), value: isValid)

            if let error {
                FieldError(message: error)
            }
        }
    }
}

// MARK: - Jauge de force du mot de passe

struct StrengthMeter: View {

    let password: String

    private var score: Int {
        var s = 0
        if password.count >= 6 { s += 1 }
        if password.count >= 10 { s += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil,
           password.rangeOfCharacter(from: .letters) != nil { s += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil,
           password.rangeOfCharacter(
                from: CharacterSet.alphanumerics.inverted
           ) != nil { s += 1 }
        return s
    }

    private var level: Int {
        if password.isEmpty { return 0 }
        if score <= 1 { return 1 }
        return score == 2 ? 2 : 3
    }

    private var color: Color {
        switch level {
        case 1: return .red
        case 2: return .orange
        default: return .green
        }
    }

    private var labelKey: String {
        switch level {
        case 1: return "strength_weak"
        case 2: return "strength_medium"
        default: return "strength_strong"
        }
    }

    var body: some View {
        if level > 0 {
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(index <= level ? color : Color(.systemGray5))
                        .frame(height: 4)
                }

                Text(tr(labelKey))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
            }
            .animation(.easeInOut(duration: 0.2), value: level)
        }
    }
}
