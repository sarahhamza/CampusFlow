//
//  LocationService.swift
//  sana
//

import Foundation
import CoreLocation

/// Récupère la position de l'utilisateur (autorisation « pendant l'utilisation »)
/// et en déduit le nom de la ville par géocodage inverse.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published private(set) var status: CLAuthorizationStatus = .notDetermined
    @Published private(set) var place: Place?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        // La météo n'a pas besoin d'une précision au mètre : économise la batterie.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        status = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var isDenied: Bool {
        status == .denied || status == .restricted
    }

    /// Demande l'autorisation si besoin, sinon actualise la position.
    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        let newStatus = manager.authorizationStatus

        Task { @MainActor in
            self.status = newStatus
            if self.isAuthorized {
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            await self.resolve(location)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Échec ponctuel (ex. position inconnue) : on garde le lieu précédent
        // ou la ville par défaut, la météo reste affichée.
    }

    // MARK: - Géocodage inverse

    private func resolve(_ location: CLLocation) async {
        var name = tr("my_position")

        if let mark = try? await geocoder
            .reverseGeocodeLocation(location)
            .first {
            name = mark.locality
                ?? mark.administrativeArea
                ?? mark.country
                ?? name
        }

        place = Place(
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}
