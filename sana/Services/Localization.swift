//
//  Localization.swift
//  sana
//

import SwiftUI

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

extension View {
    /// Titre de barre de navigation traduit dans la langue de l'app.
    /// `navigationTitle("clé")` passe par UIKit et suit la langue du système ;
    /// avec une String déjà traduite par `tr`, la langue choisie est respectée.
    func screenTitle(_ key: String) -> some View {
        navigationTitle(tr(key))
            .modifier(CampusScreenStyle())
    }
}
