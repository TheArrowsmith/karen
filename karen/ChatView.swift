import SwiftUI

struct ChatView: View {
    let messages: [ChatMessage]
    let loadingState: AppStore.ChatLoadingState // NEW
    let onRetry: () -> Void // NEW
    let onSendMessage: (String) -> Void

    @State private var inputText = ""
    @Namespace private var bottomID

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable message area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }

                        // Add this switch statement right after the ForEach loop
                        switch loadingState {
                        case .loading:
                            LoadingIndicator()
                                .padding(.top, 10)
                        case .error(let error, _):
                            ChatErrorView(error: error, onRetry: onRetry)
                                .padding(.top, 10)
                        case .idle:
                            EmptyView()
                        }
                        
                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                }
                .onChange(of: messages.count) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }

            Divider()
            
            // Input area
            ChatInputView(
                text: $inputText,
                isLoading: loadingState.isLoading, // Pass a boolean
                onSend: sendMessage
            )
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSendMessage(inputText)
        inputText = ""
    }
}

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool // NEW
    let onSend: () -> Void
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Use default TextField style which properly supports all keyboard shortcuts
            TextField("Type your message...", text: $text)
                .textFieldStyle(.automatic) // Use automatic style for proper system behavior
                .font(.system(size: 14))
                .focused($isTextFieldFocused)
                .onSubmit {
                    onSend()
                }
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isLoading ? .gray : .blue) // Update color
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading) // Update disabled condition
            .keyboardShortcut(.return, modifiers: []) // Allow Enter key to send
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            // Ensure the text field gets focus when view appears
            isTextFieldFocused = true
        }
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer(minLength: 60)
            }
            
            if message.isLoading {
                LoadingIndicator()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(16)
            } else {
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundColor(message.sender == .user ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        message.sender == .user 
                            ? Color.blue 
                            : Color(NSColor.controlBackgroundColor)
                    )
                    .cornerRadius(16)
            }
            
            if message.sender == .bot {
                Spacer(minLength: 60)
            }
        }
    }
}

struct LoadingIndicator: View {
    @State private var animationPhase = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animationPhase == Double(index) ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            animationPhase = 2.0
        }
    }
} 