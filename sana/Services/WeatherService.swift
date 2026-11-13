//
//  WeatherService.swift
//  sana
//
import Foundation

@MainActor
final class WeatherService: ObservableObject {

    @Published var snapshot: WeatherSnapshot?
    @Published var place: Place = .tunis
    @Published var loading = false
    @Published var error: String?

    /// Identifie la requête la plus récente : une réponse plus ancienne
    /// qui arrive en retard ne doit pas écraser la météo du bon lieu.
    private var latest = UUID()

    func fetch(for place: Place) async {
        var components = URLComponents(
            string: "https://api.open-meteo.com/v1/forecast"
        )

        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,relative_humidity_2m,weather_code"
            ),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else { return }

        let token = UUID()
        latest = token
        loading = true
        error = nil

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12

            let (data, response) = try await URLSession.shared
                .data(for: request)

            guard (response as? HTTPURLResponse)?
                .statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder()
                .decode(WeatherSnapshot.self, from: data)

            guard token == latest else { return }

            snapshot = decoded
            self.place = place
            loading = false

        } catch {
            guard token == latest else { return }

            loading = false

            // Tâche annulée (l'écran a disparu) : pas une vraie erreur.
            if (error as? URLError)?.code == .cancelled
                || error is CancellationError {
                return
            }

            self.error = error.localizedDescription
        }
    }
}
