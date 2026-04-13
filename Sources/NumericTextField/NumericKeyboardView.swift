// NumericKeyboardView.swift
// iOS only
#if os(iOS) && !targetEnvironment(macCatalyst)
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
		case (true, true, _):       return 1 // Full scientific and Positive real, exponent still needs "-" key
		case (true, false, true):   return 2 // Decimal with negatives
		case (true, false, false):  return 3 // Positive decimal
		case (false, _, true):      return 4 // Integer with negatives
		case (false, _, false):     return 5 // Positive integer
		}
	}
}

// MARK: - Layout builders

// Five meaningful configurations (exponent implies decimal and minus):
//   1. decimal + negative + exponent  → full scientific (default) with or without negatives
//   2. decimal + negative             → signed decimal
//   3. decimal only                   → positive decimal
//   4. negative only                  → signed integer
//   5. none                           → positive integer


private func makePortraitLayout(policy: KeyboardPolicy) -> [[KeyDef]] {
	// Use a helper to decide trailing keys based on the "keyboardCase"
	let kCase = policy.keyboardCase
	let backspace = kCase != 5 ? KeyDef(label: "⌫", value: "backspace", type: .action) : nil
	let blank     = kCase != 5 ? KeyDef(label: "", value: "", type: .blank) : nil
	let minus     = [1,2,4].contains(kCase) ? KeyDef(label: "−", value: "-", type: .special) : blank
	let eKey      = kCase == 1 ? KeyDef(label: "E", value: "E", type: .special) :  blank
	let done      = KeyDef(label: "Done",value: "done", type: .done, wide: true)
	
	let decimal = policy.allowDecimal ? policy.decimalKey : (kCase == 5 ? backspace : nil)
	
	return [
		[digit("1"), digit("2"), digit("3"), backspace].compactMap { $0 },
		[digit("4"), digit("5"), digit("6"),      eKey].compactMap { $0 },
		[digit("7"), digit("8"), digit("9"),     minus].compactMap { $0 },
		[decimal,    digit("0", wide: true),      done].compactMap { $0 },
	]
}

// Utility to reduce KeyDef boilerplate
private func digit(_ val: String, wide: Bool = false) -> KeyDef {
	KeyDef(label: val, value: val, type: .digit, wide: wide)
}

private func makeCompactHeight(policy: KeyboardPolicy) -> [[KeyDef]] {
	let topRow: [KeyDef] = [
		digit("1"), digit("2"), digit("3"),digit("4"), digit("5"), digit("6"),digit("7"), digit("8"), digit("9")
	]
	var botRow: [KeyDef] = [KeyDef(label: "0", value: "0", type: .digit)]
	if policy.allowDecimal   { botRow.append(policy.decimalKey) }
	if policy.allowNegatives || policy.allowExponent { botRow.append(KeyDef(label: "−", value: "-", type: .special)) }
	if policy.allowExponent  { botRow.append(KeyDef(label: "E", value: "E", type: .special)) }
	botRow.append(KeyDef(label: "⌫",    value: "backspace", type: .action))
	botRow.append(KeyDef(label: "Done", value: "done", type: .done, wide: true))
	return [topRow, botRow]
}

private func makeLandscapeLayout(policy: KeyboardPolicy) -> [[KeyDef]] {
	var row: [KeyDef] = [
		digit("1"), digit("2"), digit("3"),digit("4"), digit("5"), digit("6"),digit("7"), digit("8"), digit("9"), digit("0")
	]
	if policy.allowDecimal   { row.append(policy.decimalKey) }
	if policy.allowNegatives || policy.allowExponent  { row.append(KeyDef(label: "−",    value: "-", type: .special)) }
	if policy.allowExponent  { row.append(KeyDef(label: "E",    value: "E",         type: .special)) }
	row.append(KeyDef(label: "⌫",    value: "backspace", type: .action))
	row.append(KeyDef(label: "Done", value: "done",      type: .done, wide: true))
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
			.frame(height: 44)
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
		case .digit, .special, .action:
			r.fill(Color(UIColor.tertiarySystemBackground))
				.shadow(color: Color.black.opacity(0.15), radius: 0, x: 0, y: pressed ? 1 : 1.5)
		case .done:
			r.fill(Color.blue)
				.shadow(color: Color.blue.opacity(0.3), radius: 2, x: 0, y: pressed ? 1 : 2)
		case .blank:
			r.fill(Color.clear)
		}
	}
	
	private var labelColor: Color {
		switch key.type {
		case .digit:   .primary    // Black in light, White in dark
		case .special: .blue       // Stays blue but adjusts shade automatically
		case .action:  .primary    // if set to .secondary Gray in light, lighter gray in dark
		case .done:    .white      // Always white on blue button
		case .blank:   .clear
		}
	}
	
	@ViewBuilder
	private var label: some View {
		if key.value == "E" {
			VStack(spacing: 1) {
				Text("E")
					.font(.system(size: 20, weight: .regular, design: .monospaced))
					.foregroundStyle(labelColor)
				Text("×10ⁿ")
					.font(.system(size: 8))
					.foregroundStyle(labelColor)
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
}

// MARK: - Keyboard view
struct NumericKeyboardView: View {
	@Binding var text: String
	var style: NumericStringStyle = .defaultStyle
	let onDone: (String) -> Void
	var onHeightChange: ((CGFloat) -> Void)? = nil
	
	@Environment(\.horizontalSizeClass) private var hSizeClass
	@Environment(\.verticalSizeClass) private var vSizeClass
	
	private var policy: KeyboardPolicy { KeyboardPolicy(style: style) }
	
	private var activeLayout: [[KeyDef]] {
		let isLandscape = hSizeClass == .regular || vSizeClass == .compact
		if style.layout == .compactHeight && !isLandscape { return makeCompactHeight(policy: policy) }
		return isLandscape ? makeLandscapeLayout(policy: policy) : makePortraitLayout(policy: policy)
	}
	
	var body: some View {
		VStack(spacing: 0) {
			// Replaces the heavy divider/grabber with a thin subtle line
			Rectangle()
				.fill(Color.primary.opacity(0.1))
				.frame(height: 0.5)
			
			VStack(spacing: 7) { // Tighter row spacing
				ForEach(0..<activeLayout.count, id: \.self) { row in
					HStack(spacing: 7) { // Tighter key spacing
						ForEach(activeLayout[row]) { key in
							NumericKey(key: key) { handleKey(key) }
								.frame(maxWidth: .infinity)
								.frame(minWidth: key.wide ? 100 : nil)
						}
					}
				}
			}
			
			.padding(.horizontal, 6) // Minimized padding to reclaim width
			.padding(.top, 8)
			.padding(.bottom, 4) // Reduced bottom space
		}
		.background(.ultraThinMaterial) // Adaptive frosted glass
		.ignoresSafeArea(.container, edges: .horizontal)
		.background(GeometryReader { geo in
			Color.clear.onAppear { onHeightChange?(geo.size.height) }
				.onChange(of: geo.size.height) { _, h in onHeightChange?(h) }
		})
	}
	
	private func handleKey(_ key: KeyDef) {
		switch key.value {
		case "": break                          // Ignore blank keys
		case "done":
			onDone(text.isEmpty ? "0" : text)   // Finalize
		case "backspace":
			text = String(text.dropLast())      // Simple deletion
		default:
			/// For numbers, decimals, minus, and 'E': Append the new character and let the filter sanitize the result.
			let candidate = text + key.value
			text = candidate.numericValue(style: style)
		}
	}
	
}

// MARK: - Preview

#Preview {
	VStack(spacing: 0) {
		Spacer()
		// Full scientific
		NumericKeyboardView(text: .constant("3.14E-9"),
							style: .defaultStyle, onDone: { _ in })
	}
}

#endif
