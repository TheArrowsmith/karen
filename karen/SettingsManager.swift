import Foundation
import Combine

@MainActor
class SettingsManager: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "OpenAIAPIKey")
        }
    }
    
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey") ?? ""
    }
}