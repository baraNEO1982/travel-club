import SwiftUI
import UIKit

struct PasswordField: View {
    let title: String
    @Binding var text: String
    var contentType: UITextContentType = .password
    @State private var visible = false
    @FocusState private var focused: Input?
    @Environment(\.scenePhase) private var scenePhase
    private enum Input { case hidden, shown }

    init(_ title: String, text: Binding<String>, contentType: UITextContentType = .password) {
        self.title = title
        self._text = text
        self.contentType = contentType
    }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if visible {
                    TextField(title, text: $text)
                        .focused($focused, equals: .shown)
                } else {
                    SecureField(title, text: $text)
                        .focused($focused, equals: .hidden)
                }
            }
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityLabel(title)
            Button {
                let hadFocus = focused != nil
                visible.toggle()
                if hadFocus { focused = visible ? .shown : .hidden }
            } label: {
                Image(systemName: visible ? "eye.slash" : "eye")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(visible ? "Скрыть пароль" : "Показать пароль")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { visible = false }
        }
        .onDisappear { visible = false }
    }
}
