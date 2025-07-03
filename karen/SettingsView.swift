import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                Text("API Settings")
                    .font(.title2)
                
                Text("Karen uses OpenAI's models to understand your requests. Please enter your OpenAI API key below. Your key is stored locally and securely on your device.")
                    .foregroundColor(.secondary)
                
                SecureField("sk-...", text: $settingsManager.apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Link("Get your API key from the OpenAI dashboard.", destination: URL(string: "https://platform.openai.com/api-keys")!)
            }
        }
        .padding(20)
        .frame(width: 450, height: 200)
    }
}