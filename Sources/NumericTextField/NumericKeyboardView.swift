// NumericKeyboardView.swift
// iOS only
#if os(iOS)
import SwiftUI

// MARK: - Key model

private enum KeyType { case digit, special, action, done, blank }

private struct KeyDef: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let type: KeyType
    var wide: Bool = false
}

// MARK: - Style-driven policy

private struct KeyboardPolicy {
    let allowDecimal: Bool
    let allowExponent: Bool
    let allowNegatives: Bool
    let decimalKey: KeyDef

    init(style: NumericStringStyle) {
        // NumericStringStyle guarantees allowDecimal == true whenever allowExponent == true
        self.allowDecimal   = style.decimalSeparator
        self.allowExponent  = style.exponent
        self.allowNegatives = style.negatives
        let sep = Locale.current.decimalSeparator ?? "."
        self.decimalKey = KeyDef(label: sep, value: sep, type: .special)
    }
	
	var keyboardCase : Int {
		switch (allowDecimal, allowExponent, allowNegatives) {
		case (true, true, true):    return 1 // Full scientific
		case (true, true, false):   return 3 // Positive real exponent
		case (true, false, true):   return 2 // Decimal with negatives
		case (true, false, false):  return 4 // Positive decimal
		case (false, _, true):      return 5 // Integer with negatives
		case (false, _, false):     return 6 // Positive integer
		}
	}
}

// MARK: - Layout builders

// Six meaningful configurations (exponent implies decimal):
//   1. decimal + negative + exponent  → full scientific (default)
//   2. decimal + negative             → signed decimal
//   3. decimal + exponent             → positive scientific
//   4. decimal only                   → positive decimal
//   5. negative only                  → signed integer
//   6. none                           → positive integer
//
// Portrait: 4 rows of 4 keys. The 4th key in rows 2-4 varies by config.
// Landscape: 1 row — all digits + available specials + ⌫ + Done.

private func makePortraitLayout(policy: KeyboardPolicy) -> [[KeyDef]] {
    let backspace = KeyDef(label: "⌫",   value: "backspace", type: .action)
    let minus     = KeyDef(label: "−",   value: "-",         type: .special)
    let exponent  = KeyDef(label: "E",   value: "E",         type: .special)
    let done      = KeyDef(label: "Done",value: "done",      type: .done)
	let blankKey  = KeyDef(label: "", value: "", type: .blank)
	
	
	// Row 1 trailing key: backspace unless
	let row1key: KeyDef? = policy.keyboardCase != 6  ? backspace : nil
	
	// Row 2 trailing key: E if allowed
	let row2key: KeyDef? = switch policy.keyboardCase { case 2,4,5: blankKey; case 1,3: exponent; default: nil }
   
	// Row 3 trailing key: − if allowed, else E if allowed, else decimal if allowed, else blank
	let row3key: KeyDef? = switch policy.keyboardCase { case 3,4: blankKey; case 1,2,5: minus; default: nil }
	
	let row4key: KeyDef? = policy.keyboardCase == 6 ?  backspace : done

    // Row 4 leading key: decimal if allowed and not yet placed above, else blank
	let row4leading: KeyDef? = switch policy.keyboardCase { case 1,2,3,4: policy.decimalKey; case 5: blankKey; default: done}

    let row1: [KeyDef] = [
		KeyDef(label: "1", value: "1", type: .digit),
		KeyDef(label: "2", value: "2", type: .digit),
		KeyDef(label: "3", value: "3", type: .digit),
		row1key,
	].compactMap { $0 }
    let row2: [KeyDef] = [
        KeyDef(label: "4", value: "4", type: .digit),
        KeyDef(label: "5", value: "5", type: .digit),
        KeyDef(label: "6", value: "6", type: .digit),
        row2key,
	].compactMap { $0 }
    let row3: [KeyDef] = [
		KeyDef(label: "7", value: "7", type: .digit),
		KeyDef(label: "8", value: "8", type: .digit),
		KeyDef(label: "9", value: "9", type: .digit),
        row3key,
	].compactMap { $0 }
    let row4: [KeyDef] = [
		row4leading,
        KeyDef(label: "0", value: "0", type: .digit, wide: true),
		row4key,
	].compactMap { $0 }

    return [row1, row2, row3, row4]
}

private func makeLandscapeLayout(policy: KeyboardPolicy) -> [[KeyDef]] {
    var row: [KeyDef] = [
        KeyDef(label: "1", value: "1", type: .digit),
        KeyDef(label: "2", value: "2", type: .digit),
        KeyDef(label: "3", value: "3", type: .digit),
        KeyDef(label: "4", value: "4", type: .digit),
        KeyDef(label: "5", value: "5", type: .digit),
        KeyDef(label: "6", value: "6", type: .digit),
        KeyDef(label: "7", value: "7", type: .digit),
        KeyDef(label: "8", value: "8", type: .digit),
        KeyDef(label: "9", value: "9", type: .digit),
        KeyDef(label: "0", value: "0", type: .digit),
    ]
    if policy.allowDecimal   { row.append(policy.decimalKey) }
    if policy.allowNegatives { row.append(KeyDef(label: "−",    value: "-",         type: .special)) }
    if policy.allowExponent  { row.append(KeyDef(label: "E",    value: "E",         type: .special)) }
    row.append(KeyDef(label: "⌫",    value: "backspace", type: .action))
    row.append(KeyDef(label: "Done", value: "done",      type: .done))
    return [row]
}

// MARK: - Key view

private struct NumericKey: View {
    let key: KeyDef
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
            .animation(.easeOut(duration: 0.08), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(key.type == .blank)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed && key.type != .blank {
                        pressed = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .onEnded { _ in
                    pressed = false
                    if key.type != .blank { onTap() }
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
        case .blank:
            r.fill(Color.clear)
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
        case .digit, .special, .blank: return .system(size: 20, weight: .regular, design: .monospaced)
        case .action:                  return .system(size: 18, weight: .regular)
        case .done:                    return .system(size: 15, weight: .medium)
        }
    }

    private var labelColor: Color {
        switch key.type {
        case .digit:           return Color(white: 0.88)
        case .special:         return Color(red: 0.48, green: 0.72, blue: 0.98)
        case .action:          return Color(white: 0.60)
        case .done:            return .white
        case .blank:           return .clear
        }
    }
}

// MARK: - Keyboard view

struct NumericKeyboardView: View {
    @Binding var text: String
    var style: NumericStringStyle = .defaultStyle
    let onDone: (String) -> Void
	var onHeightChange: ((CGFloat) -> Void)? = nil
	
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var policy: KeyboardPolicy { KeyboardPolicy(style: style) }

    private var activeLayout: [[KeyDef]] {
        hSizeClass == .regular
            ? makeLandscapeLayout(policy: policy)
            : makePortraitLayout(policy: policy)
    }

    var body: some View {
        VStack(spacing: 10) {
            Divider().overlay(Color(white: 0.18))

            VStack(spacing: 10) {
                ForEach(0..<activeLayout.count, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(activeLayout[row]) { key in
                            NumericKey(key: key) {
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
		.background(GeometryReader { geo in   
			Color.clear.onAppear {
				onHeightChange?(geo.size.height)
			}.onChange(of: geo.size.height) { _, h in
				onHeightChange?(h)
			}
		})
    }

    private func handleKey(_ key: KeyDef) {
        guard key.type != .blank else { return }
        if key.value == "done" {
            onDone(text.isEmpty ? "0" : text)
            return
        }
		
		if key.value == "-" {
			// Allow minus ONLY at the start or immediately after an 'E'
			let canPlaceMinus = text.isEmpty || (policy.allowExponent && text.last == "E")
			if canPlaceMinus { text.append("-") }
			return
		}
		
        let candidate = key.value == "backspace"
            ? String(text.dropLast())
            : text + key.value
        text = candidate.numericValue(style: style).uppercased()
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
    VStack(spacing: 0) {
        // Full scientific
        NumericKeyboardView(text: .constant("3.14E-9"),
                            style: .defaultStyle, onDone: { _ in })
    }
}

#endif
