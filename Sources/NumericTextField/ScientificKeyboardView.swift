// ScientificKeyboardView.swift
// iOS only
#if os(iOS)
import SwiftUI

// MARK: - Key Model

enum ScientificKeyType {
    case digit, special, action, done
}

struct ScientificKeyDefinition: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let type: ScientificKeyType
    var wide: Bool = false
}

private let keyLayout: [[ScientificKeyDefinition]] = [
    [
        ScientificKeyDefinition(label: "7",    value: "7",         type: .digit),
        ScientificKeyDefinition(label: "8",    value: "8",         type: .digit),
        ScientificKeyDefinition(label: "9",    value: "9",         type: .digit),
        ScientificKeyDefinition(label: "⌫",   value: "backspace", type: .action),
    ],
    [
        ScientificKeyDefinition(label: "4",    value: "4",         type: .digit),
        ScientificKeyDefinition(label: "5",    value: "5",         type: .digit),
        ScientificKeyDefinition(label: "6",    value: "6",         type: .digit),
        ScientificKeyDefinition(label: "−",   value: "-",         type: .special),
    ],
    [
        ScientificKeyDefinition(label: "1",    value: "1",         type: .digit),
        ScientificKeyDefinition(label: "2",    value: "2",         type: .digit),
        ScientificKeyDefinition(label: "3",    value: "3",         type: .digit),
        ScientificKeyDefinition(label: "E",    value: "E",         type: .special),
    ],
    [
        ScientificKeyDefinition(label: "0",    value: "0",         type: .digit,  wide: true),
        ScientificKeyDefinition(label: ".",    value: ".",         type: .special),
        ScientificKeyDefinition(label: "Done", value: "done",      type: .done),
    ],
]

// MARK: - Individual Key View

struct ScientificKey: View {
    let key: ScientificKeyDefinition
    let isDisabled: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {}) {
            ZStack {
                keyBackground
                keyLabel
            }
            .frame(height: 54)
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .opacity(isDisabled ? 0.3 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed && !isDisabled {
                        isPressed = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    if !isDisabled { onTap() }
                }
        )
    }

    @ViewBuilder
    private var keyBackground: some View {
        switch key.type {
        case .digit:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: isPressed ? 0.28 : 0.22))
                .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: isPressed ? 1 : 3)
        case .special:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.12, green: 0.15, blue: 0.28).opacity(isPressed ? 0.9 : 1))
                .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: isPressed ? 1 : 3)
        case .action:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: isPressed ? 0.22 : 0.17))
                .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: isPressed ? 1 : 3)
        case .done:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.18, green: 0.44, blue: 0.96),
                                 Color(red: 0.12, green: 0.32, blue: 0.80)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(red: 0.1, green: 0.22, blue: 0.6).opacity(0.6),
                        radius: 4, x: 0, y: isPressed ? 1 : 3)
        }
    }

    @ViewBuilder
    private var keyLabel: some View {
        VStack(spacing: 1) {
            if key.value == "E" {
                Text("E")
                    .font(.system(size: 20, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(red: 0.48, green: 0.72, blue: 0.98))
                Text("×10ⁿ")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(Color(red: 0.4, green: 0.55, blue: 0.75))
            } else {
                Text(key.label)
                    .font(labelFont)
                    .foregroundStyle(labelColor)
            }
        }
    }

    private var labelFont: Font {
        switch key.type {
        case .digit:   return .system(size: 20, weight: .regular, design: .monospaced)
        case .special: return .system(size: 20, weight: .regular, design: .monospaced)
        case .action:  return .system(size: 18, weight: .regular)
        case .done:    return .system(size: 15, weight: .medium)
        }
    }

    private var labelColor: Color {
        switch key.type {
        case .digit:   return Color(white: 0.88)
        case .special: return Color(red: 0.48, green: 0.72, blue: 0.98)
        case .action:  return Color(white: 0.60)
        case .done:    return .white
        }
    }
}

// MARK: - Keyboard View

struct ScientificKeyboardView: View {
    @Binding var text: String
    var style: NumericStringStyle = .defaultStyle
    let onDone: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Divider()
                .overlay(Color(white: 0.18))

            VStack(spacing: 10) {
                ForEach(0..<keyLayout.count, id: \.self) { rowIndex in
                    HStack(spacing: 10) {
                        ForEach(keyLayout[rowIndex]) { key in
                            ScientificKey(
                                key: key,
                                isDisabled: isDisabled(key)
                            ) {
                                handleKey(key)
                            }
                            .frame(maxWidth: key.wide ? .infinity : nil)
                            .if(!key.wide) { $0.frame(maxWidth: .infinity) }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)

            Capsule()
                .fill(Color(white: 0.25))
                .frame(width: 134, height: 5)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
        .background(Color(red: 0.11, green: 0.13, blue: 0.19))
    }

    // MARK: - Key handling — delegate all validation to numericValue(style:)

    private func handleKey(_ key: ScientificKeyDefinition) {
        if key.value == "done" {
            onDone(text.isEmpty ? "0" : text)
            return
        }
        let candidate = key.value == "backspace"
            ? String(text.dropLast())
            : text + key.value
        text = candidate.numericValue(style: style).uppercased()
    }

    private func isDisabled(_ key: ScientificKeyDefinition) -> Bool {
        switch key.value {
        case ".": return !style.decimalSeparator
        case "E": return !style.exponent
        case "-": return !style.negatives
        default:  return false
        }
    }
}

// MARK: - Conditional modifier helper

extension View {
    @ViewBuilder
    fileprivate func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Preview

#Preview {
    ScientificKeyboardView(text: .constant("3.14E-9"), onDone: { _ in })
}

#endif
