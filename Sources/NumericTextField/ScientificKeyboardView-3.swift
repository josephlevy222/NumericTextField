// ScientificKeyboardView.swift
// iOS only
#if os(iOS)
import SwiftUI

// MARK: - Key model

private enum KeyType { case digit, special, action, done }

private struct KeyDef: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let type: KeyType
    var wide: Bool = false
}

// iPhone / iPad portrait — 4 rows
private let portraitLayout: [[KeyDef]] = [
    [
        KeyDef(label: "7",    value: "7",         type: .digit),
        KeyDef(label: "8",    value: "8",         type: .digit),
        KeyDef(label: "9",    value: "9",         type: .digit),
        KeyDef(label: "⌫",   value: "backspace", type: .action),
    ],
    [
        KeyDef(label: "4",    value: "4",         type: .digit),
        KeyDef(label: "5",    value: "5",         type: .digit),
        KeyDef(label: "6",    value: "6",         type: .digit),
        KeyDef(label: "−",   value: "-",         type: .special),
    ],
    [
        KeyDef(label: "1",    value: "1",         type: .digit),
        KeyDef(label: "2",    value: "2",         type: .digit),
        KeyDef(label: "3",    value: "3",         type: .digit),
        KeyDef(label: "E",    value: "E",         type: .special),
    ],
    [
        KeyDef(label: "0",    value: "0",         type: .digit, wide: true),
        KeyDef(label: ".",    value: ".",         type: .special),
        KeyDef(label: "Done", value: "done",      type: .done),
    ],
]

// iPad landscape — 2 rows, 8 keys each, digits 1-9,0 in order
private let landscapeLayout: [[KeyDef]] = [
    [
		KeyDef(label: "1",    value: "1",         type: .digit),
		KeyDef(label: "2",    value: "2",         type: .digit),
		KeyDef(label: "3",    value: "3",         type: .digit),
		KeyDef(label: "4",    value: "4",         type: .digit),
		KeyDef(label: "5",    value: "5",         type: .digit),
		KeyDef(label: "6",    value: "6",         type: .digit),
		KeyDef(label: "7",    value: "7",         type: .digit),
		KeyDef(label: "8",    value: "8",         type: .digit),
		KeyDef(label: "9",    value: "9",         type: .digit),
		KeyDef(label: "0",    value: "0",         type: .digit),
		KeyDef(label: ".",   value: "-",         type: .special),
		KeyDef(label: "-",    value: ".",         type: .special),
        KeyDef(label: "E",    value: "E",         type: .special),
        KeyDef(label: "⌫",   value: "backspace", type: .action),
		KeyDef(label: "Done", value: "done",      type: .done),
    ],
//    [
//        KeyDef(label: "6",    value: "6",         type: .digit),
//        KeyDef(label: "7",    value: "7",         type: .digit),
//        KeyDef(label: "8",    value: "8",         type: .digit),
//        KeyDef(label: "9",    value: "9",         type: .digit),
//        KeyDef(label: "0",    value: "0",         type: .digit),
//        KeyDef(label: "−",   value: "-",         type: .special),
//        KeyDef(label: "Done", value: "done",      type: .done),
//    ],
]

// MARK: - Key view

private struct NumericKey: View {
    let key: KeyDef
    let disabled: Bool
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {}) {
            ZStack {
                background
                label
            }
            .frame(height: 54)
            .scaleEffect(pressed ? 0.94 : 1.0)
            .opacity(disabled ? 0.3 : 1.0)
            .animation(.easeOut(duration: 0.08), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed && !disabled {
                        pressed = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .onEnded { _ in
                    pressed = false
                    if !disabled { onTap() }
                }
        )
    }

    @ViewBuilder
    private var background: some View {
        let r = RoundedRectangle(cornerRadius: 10, style: .continuous)
        switch key.type {
        case .digit:
            r.fill(Color(white: pressed ? 0.28 : 0.22))
             .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: pressed ? 1 : 3)
        case .special:
            r.fill(Color(red: 0.12, green: 0.15, blue: 0.28).opacity(pressed ? 0.9 : 1))
             .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: pressed ? 1 : 3)
        case .action:
            r.fill(Color(white: pressed ? 0.22 : 0.17))
             .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: pressed ? 1 : 3)
        case .done:
            r.fill(LinearGradient(
                colors: [Color(red: 0.18, green: 0.44, blue: 0.96),
                         Color(red: 0.12, green: 0.32, blue: 0.80)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .shadow(color: Color(red: 0.1, green: 0.22, blue: 0.6).opacity(0.6),
                    radius: 4, x: 0, y: pressed ? 1 : 3)
        }
    }

    @ViewBuilder
    private var label: some View {
        if key.value == "E" {
            VStack(spacing: 1) {
                Text("E")
                    .font(.system(size: 20, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(red: 0.48, green: 0.72, blue: 0.98))
                Text("×10ⁿ")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(red: 0.4, green: 0.55, blue: 0.75))
            }
        } else {
            Text(key.label)
                .font(labelFont)
                .foregroundStyle(labelColor)
        }
    }

    private var labelFont: Font {
        switch key.type {
        case .digit, .special: return .system(size: 20, weight: .regular, design: .monospaced)
        case .action:          return .system(size: 18, weight: .regular)
        case .done:            return .system(size: 15, weight: .medium)
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

// MARK: - Keyboard view

struct ScientificKeyboardView: View {
    @Binding var text: String
    var style: NumericStringStyle = .defaultStyle
    let onDone: (String) -> Void

    @Environment(\.horizontalSizeClass) private var hSizeClass

    // iPad (.regular) uses the compact 2-row landscape layout.
    // iPhone (.compact) uses the standard 4-row portrait layout.
    private var activeLayout: [[KeyDef]] {
        hSizeClass == .regular ? landscapeLayout : portraitLayout
    }

    var body: some View {
        VStack(spacing: 10) {
            Divider().overlay(Color(white: 0.18))

            VStack(spacing: 10) {
                ForEach(0..<activeLayout.count, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(activeLayout[row]) { key in
                            NumericKey(key: key, disabled: isDisabled(key)) {
                                handleKey(key)
                            }
                            .frame(maxWidth: .infinity)
                            .if(key.wide) { $0.frame(minWidth: 0) }
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

    private func handleKey(_ key: KeyDef) {
        if key.value == "done" {
            onDone(text.isEmpty ? "0" : text)
            return
        }
        let candidate = key.value == "backspace"
            ? String(text.dropLast())
            : text + key.value
        text = candidate.numericValue(style: style).uppercased()
    }

    private func isDisabled(_ key: KeyDef) -> Bool {
        switch key.value {
        case ".": return !style.decimalSeparator
        case "E": return !style.exponent
        case "-": return !style.negatives
        default:  return false
        }
    }
}

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
