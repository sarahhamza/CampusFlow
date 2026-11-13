//
//  Localization.swift
//  sana
//

import Foundation

/// Traduit une clé dans la langue choisie dans les réglages de l'app
/// (UserDefaults "app_language"), et non dans la langue du système.
/// À utiliser pour les textes qui ne passent pas par une vue SwiftUI
/// (messages d'erreur des services, chaînes de type String, etc.).
func tr(_ key: String) -> String {
    let code = UserDefaults.standard.string(forKey: "app_language") ?? "fr"

    guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return NSLocalizedString(key, comment: "")
    }

    return bundle.localizedString(forKey: key, value: key, table: nil)
}
