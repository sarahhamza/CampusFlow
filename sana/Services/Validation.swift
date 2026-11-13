//
//  Validation.swift
//  sana
//

import Foundation

/// Règles de validation partagées par les formulaires.
/// Chaque fonction renvoie un message déjà traduit, ou nil si la valeur est valide.
enum Validator {

    static func isValidEmail(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#,
            options: .regularExpression
        ) != nil
    }

    static func email(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return tr("msg_email_required") }
        return isValidEmail(trimmed) ? nil : tr("msg_invalid_email")
    }

    static func name(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespaces).count >= 2
            ? nil
            : tr("msg_name_short")
    }

    /// Mot de passe à la création du compte (6 caractères minimum, règle Firebase).
    static func newPassword(_ value: String) -> String? {
        if value.isEmpty { return tr("msg_password_required") }
        return value.count >= 6 ? nil : tr("msg_password_short")
    }

    /// Mot de passe à la connexion : on vérifie seulement qu'il est renseigné.
    static func loginPassword(_ value: String) -> String? {
        value.isEmpty ? tr("msg_password_required") : nil
    }

    static func confirmation(_ password: String, _ confirmation: String) -> String? {
        password == confirmation ? nil : tr("msg_password_mismatch")
    }
}
