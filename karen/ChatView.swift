import SwiftUI

struct ChatView: View {
    @Binding var messages: [ChatMessage]
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
                        
                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                }
                .onChange(of: messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }

            Divider()
            
            // Input area
            ChatInputView(text: $inputText, onSend: sendMessage)
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
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Type your message...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 14))
                .onSubmit {
                    onSend()
                }
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
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