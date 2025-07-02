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
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        guard !loadingState.isLoading else { return } // Don't send if loading
        onSendMessage(trimmedText)
        inputText = ""
    }
}

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    @FocusState private var isTextFieldFocused: Bool

    private let maxHeight: CGFloat = 150

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // This ZStack is our complete input field component
            ZStack(alignment: .topLeading) {
                // The placeholder is shown when text is empty
                if text.isEmpty {
                    Text("Type your message...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.leading, 5) // Nudge to align with TextEditor's content
                        .padding(.vertical, 8)
                }

                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .focused($isTextFieldFocused)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .background(Color.clear)
                    .frame(maxHeight: maxHeight) // Allow growth up to a limit
                    .onChange(of: text) { oldValue, newValue in
                        guard newValue.hasSuffix("\n") else { return }
                        let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                        if !isShiftPressed {
                            text = String(newValue.dropLast())
                            onSend()
                        }
                    }
                    // The TextEditor itself needs some padding to match the placeholder
                    .padding(.vertical, 8)
            }
            // --- This is the key change ---
            // Apply fixedSize to the container ZStack. This tells the parent HStack
            // that our input field's height should be determined by its content,
            // not by the available space. This solves the "huge input" problem.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isTextFieldFocused ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
            )

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isLoading || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            .onHover { isHovering in
                let shouldShowPointer = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
                if isHovering && shouldShowPointer {
                    NSCursor.pointingHand.push()
                } else if !isHovering {
                    NSCursor.pop()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
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
                    .textSelection(.enabled)
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