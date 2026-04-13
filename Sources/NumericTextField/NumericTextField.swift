// NumericTextField.swift
import SwiftUI
#if os(iOS)
import UIKit
import EditableText   // provides UIFont(font: SwiftUI.Font)
#endif

// MARK: - NumericTextField (all platforms)

/// A `TextField` replacement that limits user input to numbers. On iOS: uses NumercKeyboard instead of the system keyboard.
/// On macOS / other platforms: uses a standard TextField with NumericTextModifier.
public struct NumericTextField: View {
	#if os(iOS) && !targetEnvironment(macCatalyst)
    public init(_ title: LocalizedStringKey,
                numericText: Binding<String>,
                style: NumericStringStyle = NumericStringStyle.defaultStyle,
				keyboardStyle: NumericKeyboardLayout = .automatic,
				isFocused: Binding<FocusState<Bool>> = .constant(FocusState()),
                onEditingChanged: @escaping (Bool) -> Void = { _ in },
                onCommit: @escaping () -> Void = { },
                onNext: (() -> Void)? = nil,
				reformatter: @escaping (_ stringValue: String, _ style: NumericStringStyle) -> String = reformat) {
        self._numericText = numericText
        self.title = title
        self.style = style
		self.keyboardStyle = keyboardStyle
		self._isFocused = isFocused.wrappedValue
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
        self.onNext = onNext
        self.reformatter = reformatter
    }
	public var keyboardStyle: NumericKeyboardLayout = .automatic
	#else
	public init(_ title: LocalizedStringKey,
				numericText: Binding<String>,
				style: NumericStringStyle = NumericStringStyle.defaultStyle,
				isFocused: Binding<FocusState<Bool>> = .constant(FocusState()),
				onEditingChanged: @escaping (Bool) -> Void = { _ in },
				onCommit: @escaping () -> Void = { },
				onNext: (() -> Void)? = nil,
				reformatter: @escaping (String,NumericStringStyle) -> String = reformat) {
		self._numericText = numericText
		self.title = title
		self.style = style
		self._isFocused = isFocused.wrappedValue
		self.onEditingChanged = onEditingChanged
		self.onCommit = onCommit
		self.onNext = onNext
		self.reformatter = reformatter
	}
	#endif
    public let title: LocalizedStringKey
    @Binding public var numericText: String
    public var style: NumericStringStyle = .defaultStyle
	
	@FocusState public var isFocused

    public var onEditingChanged: (Bool) -> Void = { _ in }
    public var onCommit: () -> Void = { }
    public var onNext: (() -> Void)? = nil
	public var reformatter: (String, NumericStringStyle) -> String = reformat

    // Font storage is platform-specific:
    // iOS/Mac Catalyst: UITextField requires UIFont.
    // macOS: SwiftUI TextField takes SwiftUI.Font via .font() modifier.
#if os(iOS)
    private var _font: UIFont? = nil
#else
    private var _font: Font? = nil
#endif
    private var _textAlignment: NSTextAlignment = .natural

    // MARK: - Font modifiers

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

    // MARK: - Alignment modifiers

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

    // MARK: - Body

	public var body: some View {
#if os(iOS) && !targetEnvironment(macCatalyst)
		NumericFieldiOS(
			title,
			text: $numericText,
			style: style,
			keyboardStyle: keyboardStyle,
			isFocused: Binding(get: {isFocused},  set: { isFocused = $0}),
			font: _font,
			textAlignment: _textAlignment,
			onDone: { value in
				numericText = reformatter(value,style)
				onCommit()
				onNext?()
			},
			onFocusChange: { focused in
				if !focused { numericText = reformatter(numericText,style) }
				onEditingChanged(focused)
			}
		)
		.onAppear { numericText = reformatter(numericText,style) }
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
		}
		)
		.numericText(number: $numericText, style: style)
		.foregroundStyle(numericText.isValid(style: style) ? .primary : Color.red) // FLAG
		.focused($isFocused)
		.onChange(of: isFocused) { if !isFocused { numericText = reformatter(numericText,style) } }
		.onAppear { numericText = reformatter(numericText,style) }
		.if(_font != nil) { _ in font(_font!) }
        .multilineTextAlignment(_textAlignment.swiftUIAlignment)
#endif
    }
}

// MARK: - NSTextAlignment → SwiftUI.TextAlignment (macOS body needs this)

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
}

// MARK: - Default reformatter

public func reformat(_ string: String, style: NumericStringStyle) -> String {
	let upper = string.uppercased()
	
	// 1. Preserve Partials: If user is mid-typing, don't touch it.
	let partials = ["E", "E-", ".", ",", "-"]
	if partials.contains(where: { upper.hasSuffix($0) }) || upper.isEmpty {
		return string
	}
	
	// 2. Normalize Completed Numbers
	if let decimalValue = string.toDecimal() {
		// If it's an invalid integer, keep original so 'isValid' red color stays
		if !style.decimalSeparator && !decimalValue.isWholeNumber { return string }
		
		if style.exponent {
			let absVal = abs(decimalValue)
			// Switch to scientific only for large/tiny numbers
			if absVal >= 100_000 || (absVal > 0 && absVal <= 0.001) {
				return decimalValue.formatted(.number.notation(.scientific).precision(.significantDigits(1...6)))
			}
		}
		// Normalize: Removes leading zeros, ensures valid separator
		return decimalValue.formatted(.number.grouping(.never).precision(.significantDigits(1...20)))
	}
	return string
}

extension String {
	func toDecimal() -> Decimal? {
		// Decimal(string:locale:) handles commas vs dots automatically based on the user's region
		Decimal(string: self, locale: .current)
	}
}

// MARK: - Preview

struct NumericTextField_Previews: PreviewProvider {
    @State static var int = String("0")
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

// MARK: - iOS implementation

#if os(iOS) && !targetEnvironment(macCatalyst)

// MARK: - iOS SwiftUI wrapper

private struct NumericFieldiOS: View {
	let label: LocalizedStringKey
	@Binding var text: String
	var style: NumericStringStyle
	var keyboardStyle: NumericKeyboardLayout
	@Binding var isFocused: Bool
	var font: UIFont?
	var textAlignment: NSTextAlignment
	var onDone: (String) -> Void
	var onFocusChange: (Bool) -> Void
	
	@ScaledMetric private var scaledSize: CGFloat = 17
	
	init(_ label: LocalizedStringKey,
		 text: Binding<String>,
		 style: NumericStringStyle = .defaultStyle,
		 keyboardStyle: NumericKeyboardLayout = .automatic,
		 isFocused: Binding<Bool> = .constant(false),
		 font: UIFont? = nil,
		 textAlignment: NSTextAlignment = .natural,
		 onDone: @escaping (String) -> Void = { _ in },
		 onFocusChange: @escaping (Bool) -> Void = { _ in }) {
		self.label = label
		self._text = text
		self.style = style
		self.keyboardStyle = keyboardStyle
		self._isFocused = isFocused
		self.font = font
		self.textAlignment = textAlignment
		self.onDone = onDone
		self.onFocusChange = onFocusChange
	}
	
	private var resolvedFont: UIFont {
		font ?? .monospacedSystemFont(ofSize: scaledSize, weight: .regular)
	}
	
	var body: some View {
		let placeholderAlignment: Alignment = textAlignment == .right  ? .trailing
		: textAlignment == .center ? .center
		: .leading
		ZStack(alignment: placeholderAlignment) {
			if text.isEmpty {
				Text(label)
					.font(.system(size: resolvedFont.pointSize))
					.foregroundStyle(Color(.placeholderText))
					.frame(maxWidth: .infinity, alignment: placeholderAlignment)
					.allowsHitTesting(false)
			}
			
			NumericUITextField(
				text: $text,
				isFocused: $isFocused,
				font: resolvedFont,
				style: style,
				keyboardStyle: keyboardStyle,
				textAlignment: textAlignment,
				onDone: onDone,
				onFocusChange: onFocusChange
			)
			.frame(height: resolvedFont.pointSize * 1.6)
		}
		.onChange(of: text) { _, newValue in
			let filtered = newValue.numericValue(style: style)
			if filtered != newValue { text = filtered }
		}
	}
}

// MARK: - Text bridge

@Observable
private final class NumericTextBridge {
	var text: String
	var style: NumericStringStyle
	var keyboardStyle: NumericKeyboardLayout
	var onChange: (String) -> Void = { _ in }
	
	init(_ initial: String, style: NumericStringStyle, keyboardStyle: NumericKeyboardLayout) {
		self.text = initial
		self.style = style
		self.keyboardStyle = keyboardStyle
	}
}
// MARK: - Keyboard Style

public struct KeyboardStyle {
	var keyHeight: CGFloat
	var twoLine: Bool
	public init(keyHeight: CGFloat = 44, twoLine: Bool = false) {
		self.keyHeight = keyHeight
		self.twoLine = twoLine
	}
}

// MARK: - Keyboard host view

private struct KeyboardHost: View {
	var bridge: NumericTextBridge
	var onDone: (String) -> Void
	var onHeightChange: ((CGFloat) -> Void)? = nil

	var body: some View {
		@Bindable var bridge = bridge
		NumericKeyboardView(
			text: $bridge.text,
			style: bridge.style,
			onDone: onDone,
			onHeightChange: onHeightChange
		)
		.onChange(of: bridge.text) { _, newValue in
			bridge.onChange(newValue)
		}
	}
}
// MARK: - Keyboard container view

private class KeyboardContainerView: UIView {
	var preferredHeight: CGFloat = 260 {
		didSet { invalidateIntrinsicContentSize() }
	}
	override var intrinsicContentSize: CGSize {
		CGSize(width: UIView.noIntrinsicMetric, height: preferredHeight)
	}
}

private class BlinkingCursorView: UIView {
	func startBlinking() {
		self.isHidden = false // Ensure it's visible
		layer.removeAllAnimations()
		alpha = 1
		UIView.animate(
			withDuration: 0.5,
			delay: 0,
			options: [.repeat, .autoreverse, .allowUserInteraction],
			animations: { self.alpha = 0 }
		)
	}
	
	func stopBlinking() {
		layer.removeAllAnimations()
		alpha = 0
		isHidden = true // Strictly hide the view
	}
	
	func reposition(in field: UITextField) {
		// Only reposition if we are actually the first responder
		guard field.isFirstResponder else {
			stopBlinking()
			return
		}
		
		/// Repositions the cursor inside `field` so it sits exactly where
		/// the next keystroke will appear, respecting alignment and current text.
		guard let font = field.font else { return }
		let text = field.text ?? ""
		let fieldWidth = field.bounds.width
		let fieldHeight = field.bounds.height
		guard fieldWidth > 0 else { return }    // bounds not yet set
		
		let cursorHeight = font.lineHeight * 1.1
		let cursorY = (fieldHeight - cursorHeight) / 2
		
		let textWidth: CGFloat = text.isEmpty
		? 0
		: (text as NSString).size(withAttributes: [.font: font]).width
		
		let cursorX: CGFloat
		switch field.textAlignment {
		case .right:
			cursorX = text.isEmpty
			? fieldWidth
			: max(0, fieldWidth - textWidth)
			
		case .center:
			let textStart = (fieldWidth - textWidth) / 2
			cursorX = text.isEmpty
			? fieldWidth / 2
			: min(textStart + textWidth, fieldWidth)
			
		default: // .left, .natural
			cursorX = text.isEmpty ? 0 : min(textWidth, fieldWidth)
		}
		
		frame = CGRect(x: cursorX, y: cursorY, width: 2, height: cursorHeight)
		
		// Ensure visibility is correct at the end of repositioning
		self.isHidden = false
	}
}

// MARK: - UITextField subclass to catch layout changes

private class NumericUITextFieldView: UITextField {
	var onLayout: (() -> Void)?
	override func layoutSubviews() {
		super.layoutSubviews()
		onLayout?()
	}
}

// MARK: - UIViewRepresentable

private struct NumericUITextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var font: UIFont
    var style: NumericStringStyle
	var keyboardStyle: NumericKeyboardLayout = .automatic
    var textAlignment: NSTextAlignment
    var onDone: (String) -> Void
    var onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> NumericUITextFieldView {
        let field = NumericUITextFieldView()
        let coord = context.coordinator

        field.delegate = coord
        field.font = font
        field.textColor = .label
        field.textAlignment = textAlignment
        field.tintColor = .clear
        field.autocorrectionType = .no
        field.spellCheckingType = .no

        // Cursor as plain subview — positioned by reposition(in:)
        let cursor = BlinkingCursorView()
        cursor.backgroundColor = .systemBlue
        cursor.layer.cornerRadius = 1
        cursor.alpha = 0
        field.addSubview(cursor)
        coord.cursorView = cursor

        // Reposition cursor whenever the field lays out
        field.onLayout = { [weak field, weak coord] in
            guard let field, let coord, field.isFirstResponder else { return }
            coord.cursorView?.reposition(in: field)
        }

        // Bridge: filter all input through numericValue(style:)
        coord.bridge.onChange = { [weak field] newValue in
            let filtered = newValue.numericValue(style: coord.parent.style).uppercased()
            field?.text = filtered
            coord.parent.text = filtered
            if let field, field.isFirstResponder {
                coord.cursorView?.reposition(in: field)
            }
        }

        // Build and attach the custom keyboard
		let container = KeyboardContainerView()
		container.translatesAutoresizingMaskIntoConstraints = false
		
		let host = UIHostingController(rootView: KeyboardHost(
			bridge: coord.bridge,
			onDone: { value in
				coord.parent.onDone(value)
				field.resignFirstResponder()
			},
			onHeightChange: { [weak container] height in
				container?.preferredHeight = height
			}
		))
       
		let targetHeight = host.view.systemLayoutSizeFitting(
			CGSize(width: host.view.preferredLayoutWidth, height: UIView.layoutFittingCompressedSize.height)
		).height
		container.preferredHeight = targetHeight

        host.view.translatesAutoresizingMaskIntoConstraints = false
		host.view.backgroundColor = UIColor.systemBackground
        container.backgroundColor = host.view.backgroundColor

        container.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: container.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        field.inputView = container
        field.inputAccessoryView = UIView()
        coord.hostingController = host

        return field
    }

    func updateUIView(_ field: NumericUITextFieldView, context: Context) {
        let coord = context.coordinator

        if field.text != text {
            field.text = text
            coord.bridge.text = text
            if field.isFirstResponder {
                coord.cursorView?.reposition(in: field)
            }
        }
        if field.font != font { field.font = font }
        if field.textAlignment != textAlignment {
            field.textAlignment = textAlignment
            if field.isFirstResponder {
                coord.cursorView?.reposition(in: field)
            }
        }
        coord.parent = self
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NumericUITextField
        let bridge: NumericTextBridge
        var cursorView: BlinkingCursorView?
        var hostingController: UIHostingController<KeyboardHost>?

        init(_ parent: NumericUITextField) {
            self.parent = parent
			self.bridge = NumericTextBridge(parent.text, style: parent.style, keyboardStyle: parent.keyboardStyle)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFocused = true
            cursorView?.startBlinking()
			cursorView?.reposition(in: textField)
            parent.onFocusChange(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFocused = false
            cursorView?.stopBlinking()
            parent.text = bridge.text
            parent.onFocusChange(false)
			// Flag color on end
			textField.textColor = parent.text.isValid(style: parent.style) ? .label : .systemRed
        }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool { false }
    }
}

extension UIView {
	var preferredLayoutWidth: CGFloat {
		if #available(iOS 26.0, *) {
			// In iOS 26+, we avoid UIScreen.main entirely.
			// We use the window's width or the scene's coordinate space.
			return self.window?.windowScene?.screen.bounds.width ?? 0
		} else {
			// For older versions, the old way is still valid and won't warn.
			return UIScreen.main.bounds.width
		}
	}
}
#endif

public struct NumericTextModifier: ViewModifier {
	/// The string that the text field is bound to
	/// A number that will be updated when the `text` is updated.
	@Binding public var number: String
	/// Should the user be allowed to enter a decimal number, or an integer, etc.
	public var style = NumericStringStyle()
	
	/// - Parameters:
	///   - number:: The string 'number" that this should observe and filter
	///   - style:: The style of number allowed/formatted
	//    public func body(content: Content) -> some View {
	//        content
	//            .onChange(of: number) { _, newValue in
	//                number = newValue.numericValue(style: style).uppercased()
	//            }
	//    }
	public func body(content: Content) -> some View {
		content
			.foregroundStyle(number.isValid(style: style) ? .primary : Color.red)
			.onChange(of: number) { _, newValue in
				number = newValue.numericValue(style: style)
			}
	}
}

public extension View {
	/// A modifier that observes any changes to a string, and updates that string to remove any non-numeric characters.
	/// It also will convert that string to a `NSNumber` for easy use.
	func numericText(number: Binding<String>, style: NumericStringStyle) -> some View {
		modifier(NumericTextModifier( number: number, style: style))
	}
}
