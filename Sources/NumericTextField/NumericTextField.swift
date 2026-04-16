//
//  NumericTextField.swift
//  NumericTextFieldTester
//
//  Created by Joseph Levy on 4/13/26.
//


// NumericTextField.swift
import SwiftUI
#if os(iOS)
import UIKit
import EditableText   // provides UIFont(font: SwiftUI.Font)
#endif

// MARK: - NumericTextField

/// A `TextField` replacement that limits user input to numbers.
/// On iOS (non-Catalyst): uses a custom numeric keyboard.
/// On macOS / Catalyst: uses a standard TextField with NumericTextModifier.
public struct NumericTextField: View {
#if os(iOS) && !targetEnvironment(macCatalyst)
	public init(_ title: LocalizedStringKey,
				numericText: Binding<String>,
				style: NumericStringStyle = .defaultStyle,
				keyboardStyle: NumericKeyboardLayout = .automatic,
				isFocused: Binding<FocusState<Bool>> = .constant(FocusState()),
				onEditingChanged: @escaping (Bool) -> Void = { _ in },
				onCommit: @escaping () -> Void = { },
				onNext: (() -> Void)? = nil,
				reformatter: @escaping (_ stringValue: String, _ style: NumericStringStyle) -> String = reformat,
				validationHelpText: ((_ stringValue: String, _ style: NumericStringStyle) -> String?)? = nil) {
		self._numericText = numericText
		self.title = title
		self.style = style
		self.keyboardStyle = keyboardStyle
		self._isFocused = isFocused.wrappedValue
		self.onEditingChanged = onEditingChanged
		self.onCommit = onCommit
		self.onNext = onNext
		self.reformatter = reformatter
		self.validationHelpText = validationHelpText
	}
	public var keyboardStyle: NumericKeyboardLayout = .automatic
#else
	public init(_ title: LocalizedStringKey,
				numericText: Binding<String>,
				style: NumericStringStyle = .defaultStyle,
				isFocused: Binding<FocusState<Bool>> = .constant(FocusState()),
				onEditingChanged: @escaping (Bool) -> Void = { _ in },
				onCommit: @escaping () -> Void = { },
				onNext: (() -> Void)? = nil,
				reformatter: @escaping (String, NumericStringStyle) -> String = reformat,
				validationHelpText: ((_ stringValue: String, _ style: NumericStringStyle) -> String?)? = nil) {
		self._numericText = numericText
		self.title = title
		self.style = style
		self._isFocused = isFocused.wrappedValue
		self.onEditingChanged = onEditingChanged
		self.onCommit = onCommit
		self.onNext = onNext
		self.reformatter = reformatter
		self.validationHelpText = validationHelpText
	}
#endif

	public let title: LocalizedStringKey
	@Binding public var numericText: String
	public var style: NumericStringStyle = .defaultStyle
	@FocusState public var isFocused: Bool

	public var onEditingChanged: (Bool) -> Void = { _ in }
	public var onCommit: () -> Void = { }
	public var onNext: (() -> Void)? = nil
	public var reformatter: (String, NumericStringStyle) -> String = reformat
	public var validationHelpText: ((_ stringValue: String, _ style: NumericStringStyle) -> String?)? = nil
	@State private var isShowingValidationHelpAlert = false

	private var activeValidationHelpText: String? {
		guard !numericText.isValid(style: style) else { return nil }
		guard let helpText = validationHelpText?(numericText, style), !helpText.isEmpty else { return nil }
		return helpText
	}

#if os(iOS)
	private var _font: UIFont? = nil
#else
	private var _font: Font? = nil
#endif
	private var _textAlignment: NSTextAlignment = .natural

	// MARK: Font modifiers

#if os(iOS)
	/// Sets the font using a SwiftUI.Font — converted to UIFont via EditableText.
	public func font(_ font: Font) -> NumericTextField {
		var copy = self; copy._font = UIFont(font: font); return copy
	}
	/// Sets the font using a UIFont directly.
	public func font(_ font: UIFont) -> NumericTextField {
		var copy = self; copy._font = font; return copy
	}
#else
	/// Sets the font using a SwiftUI.Font.
	public func font(_ font: SwiftUI.Font) -> NumericTextField {
		var copy = self; copy._font = font; return copy
	}
#endif

	// MARK: Alignment modifiers

	/// Sets text alignment using SwiftUI TextAlignment.
	public func textAlignment(_ alignment: TextAlignment) -> NumericTextField {
		var copy = self
		copy._textAlignment = switch alignment {
			case .leading:  .left
			case .center:   .center
			case .trailing: .right
		}
		return copy
	}

	/// Sets text alignment using NSTextAlignment directly.
	public func textAlignment(_ alignment: NSTextAlignment) -> NumericTextField {
		var copy = self; copy._textAlignment = alignment; return copy
	}

	// MARK: Body

	public var body: some View {
		let validationHelpToShow = activeValidationHelpText
#if os(iOS) && !targetEnvironment(macCatalyst)
		NumericFieldiOS(
			title,
			text: $numericText,
			style: style,
			keyboardStyle: keyboardStyle,
			isFocused: Binding(get: { isFocused }, set: { isFocused = $0 }),
			font: _font,
			textAlignment: _textAlignment,
			onDone: { value in
				numericText = reformatter(value, style)
				onCommit()
				onNext?()
			},
			onFocusChange: { focused in
				if !focused { numericText = reformatter(numericText, style) }
				onEditingChanged(focused)
			}
		)
		.onAppear { numericText = reformatter(numericText, style) }
		.onChange(of: numericText) { _, newValue in
			let hasValidationHelp = !newValue.isValid(style: style) && (validationHelpText?(newValue, style)?.isEmpty == false)
			if !hasValidationHelp { isShowingValidationHelpAlert = false }
		}
		.ifLet(validationHelpToShow) { view, helpText in
			view
				.onLongPressGesture { isShowingValidationHelpAlert = true }
				.accessibilityAction(named: Text("Show validation help")) {
					isShowingValidationHelpAlert = true
				}
				.alert(helpText, isPresented: $isShowingValidationHelpAlert) {
					Button("OK", role: .cancel) { }
				}
		}
		//.onChange(of: numericText) { isValid = numericText.isValid(style: style)}
#else
		TextField(title, text: $numericText,
				  onEditingChanged: { exited in
			if exited { numericText = reformatter(numericText, style) }
			onEditingChanged(exited)
		},
				  onCommit: {
			numericText = reformatter(numericText, style)
			onCommit()
			onNext?()
		})
		.numericText(number: $numericText, style: style)
		.focused($isFocused)
		.onChange(of: isFocused) { if !isFocused { numericText = reformatter(numericText, style) } }
		.onAppear { numericText = reformatter(numericText, style) }
		.if(_font != nil) { _ in font(_font!) }
		.multilineTextAlignment(_textAlignment.swiftUIAlignment)
		.ifLet(validationHelpToShow) { view, helpText in
			view.help(helpText)
		}
#endif
	}
}

// MARK: - NSTextAlignment → SwiftUI.TextAlignment

private extension NSTextAlignment {
	var swiftUIAlignment: TextAlignment {
		switch self {
		case .right:  return .trailing
		case .center: return .center
		default:      return .leading
		}
	}
}

// MARK: - Conditional view modifier helper

private extension View {
	@ViewBuilder
	func `if`<C: View>(_ condition: Bool, transform: (Self) -> C) -> some View {
		if condition { transform(self) } else { self }
	}

	@ViewBuilder
	func ifLet<T, C: View>(_ value: T?, transform: (Self, T) -> C) -> some View {
		if let value { transform(self, value) } else { self }
	}
}

// MARK: - Default reformatter

public func reformat(_ string: String, style: NumericStringStyle) -> String {
	let upper = string.uppercased()

	// Preserve partials: don't reformat while user is mid-typing.
	let partials = ["E", "E-", ".", ",", "-"]
	if partials.contains(where: { upper.hasSuffix($0) }) || upper.isEmpty {
		return string
	}

	if let decimalValue = string.toDecimal() {
		// Keep original if integer style but value has a fractional part (keeps red flag)
		if !style.decimalSeparator && !decimalValue.isWholeNumber { return string }

		if style.exponent {
			let absVal = abs(decimalValue)
			if absVal >= 100_000 || (absVal > 0 && absVal <= 0.001) {
				return decimalValue.formatted(.number.notation(.scientific).precision(.significantDigits(1...6)))
			}
		}
		return decimalValue.formatted(.number.grouping(.never).precision(.significantDigits(1...20)))
	}
	return string
}

// MARK: - NumericTextModifier

public struct NumericTextModifier: ViewModifier {
	@Binding public var number: String
	@State private var textColor = Color.primary
	public var style = NumericStringStyle()

	public func body(content: Content) -> some View {
		content
			.foregroundStyle(textColor)
			.onChange(of: number) { _, newValue in
				number = newValue.numericValue(style: style)
				textColor = number.isValid(style: style) ? .primary : .red
			}
	}
}

public extension View {
	/// Observes changes to a string and filters it to only allow numeric characters per `style`.
	func numericText(number: Binding<String>, style: NumericStringStyle) -> some View {
		modifier(NumericTextModifier(number: number, style: style))
	}
}

// MARK: - Preview

struct NumericTextField_Previews: PreviewProvider {
	@State static var int    = String("0")
	@State static var double = String("0")

	static var previews: some View {
		VStack {
			HStack {
				NumericTextField("Int", numericText: $int,
								 style: NumericStringStyle(decimalSeparator: false))
					.textAlignment(.trailing)
					.frame(width: 200)
					.border(.foreground, width: 1)
					.padding()
				Text(int + " is the Int")
			}
			HStack {
				NumericTextField("Double", numericText: $double)
					.font(.system(size: 20, weight: .light, design: .monospaced))
					.textAlignment(.trailing)
					.frame(width: 200)
					.border(.foreground, width: 1)
					.padding()
				Text(double + " is the double")
			}
		}
	}
}
