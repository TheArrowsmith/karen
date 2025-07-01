import SwiftUI

struct ChatErrorView: View {
    let error: APIError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("An error occurred")
                .font(.headline)
                .foregroundColor(.red)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Tap to Retry", action: onRetry)
                .buttonStyle(.bordered)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(NSColor.unemphasizedSelectedContentBackgroundColor))
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }
} 