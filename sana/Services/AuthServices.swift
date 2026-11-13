//
//  AuthServices.swift
//  sana
//
//  Created by Tekup-mac-4 on 6/11/2026.
//

import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

@MainActor
final class AuthService: ObservableObject {

    @Published private(set) var user: User?
    @Published var unlockedUID: String?
    @Published var working = false
    @Published var message: String?

    private var listener: AuthStateDidChangeListenerHandle?

    var configured: Bool {
        FirebaseApp.app() != nil
    }

    init() {
        if FirebaseApp.app() != nil {
            listener = Auth.auth().addStateDidChangeListener {
                [weak self] _, user in

                Task { @MainActor in
                    self?.user = user
                }
            }
        }
    }

    func login(email: String, password: String) async {
        if let problem = Validator.email(email)
            ?? Validator.loginPassword(password) {
            message = problem
            return
        }

        await perform {
            _ = try await Auth.auth().signIn(
                withEmail: email.trimmingCharacters(
                    in: .whitespaces
                ),
                password: password
            )
        }
    }

    func register(
        name: String,
        email: String,
        password: String
    ) async {

        if let problem = Validator.name(name)
            ?? Validator.email(email)
            ?? Validator.newPassword(password) {
            message = problem
            return
        }

        await perform {
            let result = try await Auth.auth()
                .createUser(
                    withEmail: email,
                    password: password
                )

            let change = result.user.createProfileChangeRequest()
            change.displayName = name

            try await change.commitChanges()

            try await Firestore.firestore()
                .collection("users")
                .document(result.user.uid)
                .setData([
                    "name": name,
                    "email": email,
                    "createdAt": FieldValue.serverTimestamp()
                ])
        }
    }

    func reset(email: String) async {
        if let problem = Validator.email(email) {
            message = problem
            return
        }

        await perform {
            try await Auth.auth()
                .sendPasswordReset(withEmail: email)
        }

        if message == nil {
            message = tr("msg_reset_sent")
        }
    }

    func googleLogin() async {
        guard let clientID = FirebaseApp.app()?
            .options.clientID else {
            message = tr("msg_firebase_missing")
            return
        }

        guard let controller = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            message = tr("msg_google_unavailable")
            return
        }

        await perform {
            GIDSignIn.sharedInstance.configuration =
                GIDConfiguration(clientID: clientID)

            let result = try await GIDSignIn.sharedInstance
                .signIn(withPresenting: controller)

            guard let token = result.user.idToken?
                .tokenString else {
                throw NSError(
                    domain: "GoogleSignIn",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            tr("msg_google_token")
                    ]
                )
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: token,
                accessToken: result.user.accessToken.tokenString
            )

            let signedIn = try await Auth.auth()
                .signIn(with: credential)

            try await Firestore.firestore()
                .collection("users")
                .document(signedIn.user.uid)
                .setData([
                    "name": signedIn.user.displayName ?? "",
                    "email": signedIn.user.email ?? "",
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        }
    }

    func logout() {
        unlockedUID = nil
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            message = error.localizedDescription
        }
    }

    private func perform(
        _ operation: () async throws -> Void
    ) async {
        working = true
        message = nil

        defer { working = false }

        do {
            try await operation()
        } catch {
            message = friendlyMessage(for: error)
        }
    }

    /// Transforme les erreurs techniques Firebase / Google en messages clairs et traduits.
    /// Renvoie nil quand l'utilisateur a simplement annulé (pas d'alerte à afficher).
    private func friendlyMessage(for error: Error) -> String? {
        let ns = error as NSError

        // Google Sign-In : fenêtre fermée par l'utilisateur (code -5)
        if ns.domain == "com.google.GIDSignIn", ns.code == -5 {
            return nil
        }

        if ns.domain == "FIRAuthErrorDomain",
           let code = AuthErrorCode.Code(rawValue: ns.code) {
            switch code {
            case .invalidEmail:
                return tr("msg_invalid_email")
            case .wrongPassword, .userNotFound, .invalidCredential:
                return tr("err_bad_credentials")
            case .emailAlreadyInUse:
                return tr("err_email_in_use")
            case .weakPassword:
                return tr("msg_password_short")
            case .networkError:
                return tr("err_network")
            case .tooManyRequests:
                return tr("err_too_many")
            case .userDisabled:
                return tr("err_user_disabled")
            default:
                break
            }
        }

        return error.localizedDescription
    }
}
