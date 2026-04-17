//
//  NumericTextField.swift
//
//  Created by Joseph Levy on 4/13/26.
//

// NumericTextField.swift
import SwiftUI

// MARK: - NumericTextField

/// A `TextField` replacement that limits user input to numbers.
/// On iOS (non-Catalyst): uses a custom numeric keyboard.
/// On macOS / Catalyst: uses a standard TextField with NumericTextModifier.
public struct NumericTextField: View {
	public init(_ title: LocalizedStringKey,
				numericText: Binding<String>,
				style: NumericStringStyle = .defaultStyle,
				keyboardStyle: NumericKeyboardLayout = .automatic,
				isFocused: Binding<FocusState<Bool>> = .constant(FocusState()),
				onEditingChanged: @escaping (Bool) -> Void = { _ in },
				onCommit: @escaping () -> Void = { },
				onNext: (() -> Void)? = nil,
				reformatter:  ( (_ style: NumericStringStyle) -> String)? = nil,
				validationHelpText: ((_ stringValue: String, _ style: NumericStringStyle) -> String?)? = nil) {
		self._numericText = numericText
					self.title = title
		self.style = style
		self.keyboardStyle = keyboardStyle
		self._isFocused = isFocused.wrappedValue
		self.onEditingChanged = onEditingChanged
		self.onCommit = onCommit
		self.onNext = onNext
		self.reformatter = reformatter ?? numericText.wrappedValue.reformat
		self.validationHelpText = validationHelpText ?? validationMessage
	}
	public var keyboardStyle: NumericKeyboardLayout = .automatic

	public let title: LocalizedStringKey
	@Binding public var numericText: String
	public var style: NumericStringStyle = .defaultStyle
	@FocusState public var isFocused: Bool
	private var focusBinding: Binding<Bool> { Binding( get: { isFocused}, set: { isFocused = $0})}
	public var onEditingChanged: (Bool) -> Void = { _ in }
	public var onCommit: () -> Void = { }
	public var onNext: (() -> Void)? = nil
	public var reformatter: (_ style: NumericStringStyle) -> String
	public var validationHelpText: ((_ stringValue: String, _ style: NumericStringStyle) -> String?)?
	@State private var isShowingValidationHelp = false
	
	private var activeValidationHelpText: String? {
		deriveValidationHelpText(for: numericText)
	}
	
	private func deriveValidationHelpText(for value: String) -> String? {
		guard !value.isValid(style: style),
			  let helpText = validationHelpText?(value, style), !helpText.isEmpty else { return nil }
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
		//let validationHelpToShow = activeValidationHelpText
#if os(iOS) && !targetEnvironment(macCatalyst)
		NumericFieldiOS(
			title,
			text: $numericText,
			style: style,
			keyboardStyle: keyboardStyle,
			isFocused: focusBinding,
			font: _font,
			textAlignment: _textAlignment,
			onDone: { value in
				numericText = reformatter(style)
				onCommit()
				onNext?()
			},
			onFocusChange: { focused in
				if !focused { numericText = reformatter( style) }
				onEditingChanged(focused)
			}
		)
		.onAppear { numericText = reformatter(style) }
		.errorOverlay(activeValidationHelpText, isFocused: focusBinding)
#else
		TextField(title, text: $numericText,
				  onEditingChanged: { exited in
			if exited { numericText = reformatter(style) }
			onEditingChanged(exited)
		},
				  onCommit: {
			numericText = reformatter(style)
			onCommit()
			onNext?()
		})
		.numericText(number: $numericText, style: style)
		.focused($isFocused)
		.onChange(of: isFocused) { if !isFocused { numericText = reformatter(style) } }
		.onAppear { numericText = reformatter(style) }
		.if(_font != nil) { _ in font(_font!) }
		.multilineTextAlignment(_textAlignment.swiftUIAlignment)
		.errorOverlay(activeValidationHelpText)
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
