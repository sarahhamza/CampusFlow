//
//  AuthViews.swift
//  sana
//
//  Created by Tekup-mac-4 on 6/11/2026.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject var auth: AuthService
    @StateObject private var store = StudyStore()

    var body: some View {
        Group {
            if !auth.configured {
                ConfigurationView()
            } else if let user = auth.user {
                MainTabs()
                    .environmentObject(store)
                    .task(id: user.uid) {
                        store.start(uid: user.uid)
                    }
            } else {
                WelcomeView()
                    .onAppear {
                        store.stop()
                    }
            }
        }
        .animation(
            .easeInOut(duration: 0.25),
            value: auth.user?.uid
        )
        .alert(
            tr("notice"),
            isPresented: Binding(
                get: { auth.message != nil },
                set: {
                    if !$0 { auth.message = nil }
                }
            )
        ) {
            Button(tr("ok"), role: .cancel) {
                auth.message = nil
            }
        } message: {
            Text(auth.message ?? "")
        }
    }
}

struct ConfigurationView: View {
    var body: some View {
        ContentUnavailableView(
            "config_required",
            systemImage: "gearshape.2",
            description: Text("config_hint")
        )
    }
}

struct WelcomeView: View {

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "graduationcap.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.indigo)
                    .symbolEffect(.pulse)

                Text("CampusFlow")
                    .font(.largeTitle.bold())

                Text("welcome_subtitle")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Spacer()

                NavigationLink(destination: LoginView()) {
                    Text("login")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink(destination: RegisterView()) {
                    Text("register")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
            }
            .padding(28)
        }
    }
}

/// Message d'erreur affiché sous un champ de formulaire.
struct FieldError: View {

    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct LoginView: View {

    @EnvironmentObject var auth: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var submitted = false

    // Les erreurs n'apparaissent qu'après une première tentative,
    // puis se mettent à jour en direct pendant la saisie.
    private var emailError: String? {
        submitted ? Validator.email(email) : nil
    }

    private var passwordError: String? {
        submitted ? Validator.loginPassword(password) : nil
    }

    var body: some View {
        Form {
            Section("login") {
                TextField("email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if let emailError {
                    FieldError(message: emailError)
                }

                SecureField("password", text: $password)
                    .textContentType(.password)

                if let passwordError {
                    FieldError(message: passwordError)
                }

                Button("login") {
                    submitted = true

                    guard Validator.email(email) == nil,
                          Validator.loginPassword(password) == nil
                    else { return }

                    Task {
                        await auth.login(
                            email: email,
                            password: password
                        )
                    }
                }
                .disabled(auth.working)
            }

            Section {
                Button {
                    Task {
                        await auth.googleLogin()
                    }
                } label: {
                    Label(
                        "google_login",
                        systemImage: "person.crop.circle"
                    )
                }
                .disabled(auth.working)

                NavigationLink(
                    "forgot_password",
                    destination: ResetPasswordView()
                )
            }

            if auth.working {
                ProgressView("loading")
            }
        }
        .animation(.easeInOut(duration: 0.25), value: emailError)
        .animation(.easeInOut(duration: 0.25), value: passwordError)
        .screenTitle("login")
    }
}

struct RegisterView: View {

    @EnvironmentObject var auth: AuthService

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var submitted = false

    private var nameError: String? {
        submitted ? Validator.name(name) : nil
    }

    private var emailError: String? {
        submitted ? Validator.email(email) : nil
    }

    private var passwordError: String? {
        submitted ? Validator.newPassword(password) : nil
    }

    private var confirmationError: String? {
        submitted ? Validator.confirmation(password, confirmation) : nil
    }

    private var isValid: Bool {
        Validator.name(name) == nil
            && Validator.email(email) == nil
            && Validator.newPassword(password) == nil
            && Validator.confirmation(password, confirmation) == nil
    }

    var body: some View {
        Form {
            Section("register") {
                TextField("name", text: $name)
                    .textContentType(.name)

                if let nameError {
                    FieldError(message: nameError)
                }

                TextField("email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if let emailError {
                    FieldError(message: emailError)
                }

                SecureField("password", text: $password)
                    .textContentType(.newPassword)

                if let passwordError {
                    FieldError(message: passwordError)
                }

                SecureField(
                    "confirm_password",
                    text: $confirmation
                )

                if let confirmationError {
                    FieldError(message: confirmationError)
                }
            }

            Section {
                Button("create_account") {
                    submitted = true

                    guard isValid else { return }

                    Task {
                        await auth.register(
                            name: name,
                            email: email,
                            password: password
                        )
                    }
                }
                .disabled(auth.working)

                if auth.working {
                    ProgressView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: nameError)
        .animation(.easeInOut(duration: 0.25), value: emailError)
        .animation(.easeInOut(duration: 0.25), value: passwordError)
        .animation(.easeInOut(duration: 0.25), value: confirmationError)
        .screenTitle("register")
    }
}

struct ResetPasswordView: View {

    @EnvironmentObject var auth: AuthService

    @State private var email = ""
    @State private var submitted = false

    private var emailError: String? {
        submitted ? Validator.email(email) : nil
    }

    var body: some View {
        Form {
            Section("forgot_password") {
                TextField("email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if let emailError {
                    FieldError(message: emailError)
                }

                Button("send_reset") {
                    submitted = true

                    guard Validator.email(email) == nil else { return }

                    Task {
                        await auth.reset(email: email)
                    }
                }
                .disabled(auth.working)

                if auth.working {
                    ProgressView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: emailError)
        .screenTitle("forgot_password")
    }
}
