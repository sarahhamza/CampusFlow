import Foundation
import FirebaseFunctions

@MainActor
final class RevisionService: ObservableObject {
    @Published private(set) var working = false
    @Published private(set) var plan: RevisionPlan?
    @Published var error: String?

    func generate(subjects: String, days: Int, minutes: Int, language: String) async {
        guard !working else { return }
        working = true
        error = nil
        plan = nil
        defer { working = false }
        do {
            let result = try await Functions.functions().httpsCallable("generateRevisionPlan").call([
                "subjects": subjects, "days": days, "minutes": minutes, "language": language
            ])
            let data = try JSONSerialization.data(withJSONObject: result.data)
            let decoded = try JSONDecoder().decode(RevisionPlan.self, from: data)
            guard !decoded.sessions.isEmpty, decoded.sessions.count <= 84,
                  decoded.sessions.allSatisfy({ (1...days).contains($0.day) && (10...minutes).contains($0.minutes) }) else {
                throw NSError(domain: "Revision", code: 1, userInfo: [NSLocalizedDescriptionKey: tr("ai_invalid")])
            }
            plan = decoded
        } catch {
            self.error = tr("ai_failed")
        }
    }
}
