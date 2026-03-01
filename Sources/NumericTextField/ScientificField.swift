// ScientificField.swift
// iOS only
#if os(iOS)
import SwiftUI

/// A SwiftUI drop-in replacement for TextField that accepts only scientific numeric input.
/// Uses ScientificKeyboard instead of the system keyboard.
/// Matches TextField behaviour: placeholder visible when empty, hidden once text is entered.
public struct ScientificField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var style: NumericStringStyle
    var onDone: (String) -> Void
    var onFocusChange: (Bool) -> Void

    @State private var isFocused = false
    @State private var isValid = true

    // Scales with the user's Dynamic Type setting
    @ScaledMetric private var fontSize: CGFloat = 17

    public init(_ label: LocalizedStringKey,
                text: Binding<String>,
                style: NumericStringStyle = .defaultStyle,
                onDone: @escaping (String) -> Void = { _ in },
                onFocusChange: @escaping (Bool) -> Void = { _ in }) {
        self.label = label
        self._text = text
        self.style = style
        self.onDone = onDone
        self.onFocusChange = onFocusChange
    }

    public var body: some View {
        ZStack(alignment: .trailing) {

            // Placeholder — visible only when empty, just like a native TextField
            if text.isEmpty {
				if #available(iOS 17.0, *) {
					Text(label)
						.font(.system(size: fontSize))
						.foregroundStyle(Color(.placeholderText))
						.frame(maxWidth: .infinity, alignment: .leading)
						.allowsHitTesting(false)
				} else {
					// Fallback on earlier versions
				}
            }

            ScientificTextField(
                text: $text,
                placeholder: "",   // we draw our own placeholder above
                font: .monospacedSystemFont(ofSize: fontSize, weight: .regular),
                style: style,
                onDone: { value in
                    isValid = isValidScientific(value)
                    onDone(value)
                },
                onFocusChange: { focused in
                    withAnimation(.easeOut(duration: 0.15)) { isFocused = focused }
                    if !focused { isValid = isValidScientific(text) }
                    onFocusChange(focused)
                }
            )
            .frame(height: fontSize * 1.6)

            // Clear button — shown while focused and non-empty
            if isFocused && !text.isEmpty {
                Button {
                    text = ""
                    isValid = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(.tertiaryLabel))
                        .font(.system(size: fontSize * 0.85))
                }
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(borderColor)
                .frame(height: isFocused ? 2 : 1)
                .animation(.easeOut(duration: 0.15), value: isFocused)
                .animation(.easeOut(duration: 0.15), value: isValid)
        }
        .overlay(alignment: .bottomLeading) {
            if !isValid {
                Text("Enter a valid number")
                    .font(.system(size: fontSize * 0.7))
                    .foregroundStyle(.red)
                    .offset(y: fontSize * 0.9)
                    .transition(.opacity)
            }
        }
        .padding(.bottom, isValid ? 4 : fontSize)
        .onChange(of: text) { _, newValue in
            // Live-filter via the package's own validation
            let filtered = newValue.numericValue(style: style).uppercased()
            if filtered != newValue { text = filtered }
            if !isValid { isValid = isValidScientific(newValue) }
        }
    }

    // MARK: - Helpers

    private var borderColor: Color {
        if !isValid { return .red }
        if isFocused { return .accentColor }
        return Color(.separator)
    }

    /// Accepts complete numbers and valid intermediate states still being typed.
    private func isValidScientific(_ value: String) -> Bool {
        if value.isEmpty { return true }
        if Double(value) != nil { return true }
        return value == "-" ||
               value.hasSuffix("E") ||
               value.hasSuffix("E-")
    }
}

#Preview {
    @Previewable @State var wavelength = ""
    @Previewable @State var voltage = ""
    @Previewable @State var count = ""

    Form {
        ScientificField("Wavelength (m)", text: $wavelength)
        ScientificField("Voltage (V)", text: $voltage)
        ScientificField("Count", text: $count, style: .intStyle)
    }
}

#endif
