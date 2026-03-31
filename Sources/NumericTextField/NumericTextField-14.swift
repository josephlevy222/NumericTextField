// NumericTextField.swift
#if false// Used on iOS 17+ where the Observation framework is available.
// On iOS 15-16 NumericTextField+iOS15.swift is used instead.
#if canImport(Observation)
import SwiftUI
#if os(iOS)
import UIKit
import EditableText   // provides UIFont(font: SwiftUI.Font)
#endif

// MARK: - NumericTextField (all platforms)

/// A `TextField` replacement that limits user input to numbers.
/// On iOS: uses ScientificKeyboard instead of the system keyboard.
/// On macOS / other platforms: uses a standard TextField with NumericTextModifier.
public struct NumericTextField: View {
    public init(_ title: LocalizedStringKey,
                numericText: Binding<String>,
                style: NumericStringStyle = NumericStringStyle.defaultStyle,
                onEditingChanged: @escaping (Bool) -> Void = { _ in },
                onCommit: @escaping () -> Void = { },
                reformatter: @escaping (String) -> String = reformat) {
        self._numericText = numericText
        self.title = title
        self.style = style
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
        self.reformatter = reformatter
    }

    public let title: LocalizedStringKey
    @Binding public var numericText: String
    public var style: NumericStringStyle = .defaultStyle
    public var onEditingChanged: (Bool) -> Void = { _ in }
    public var onCommit: () -> Void = { }
    public var reformatter: (_ stringValue: String) -> String = reformat

    // Set via modifiers
    private var _font: UIFont? = nil
    private var _textAlignment: NSTextAlignment = .natural

    // MARK: - Font modifiers

    /// Sets the font using a SwiftUI.Font — same syntax as .font() on any SwiftUI view.
    /// Uses UIFont(font:) from EditableText to convert SwiftUI.Font → UIFont.
    /// If not called, defaults to a monospaced system font scaled to the current Dynamic Type size.
    public func font(_ font: SwiftUI.Font) -> NumericTextField {
        var copy = self
        copy._font = UIFont(font: font)
        return copy
    }

    /// Sets the font using a UIFont directly.
    public func font(_ font: UIFont) -> NumericTextField {
        var copy = self
        copy._font = font
        return copy
    }

    // MARK: - Alignment modifiers

    /// Sets the text alignment using SwiftUI's TextAlignment.
    public func textAlignment(_ alignment: TextAlignment) -> NumericTextField {
        var copy = self
        copy._textAlignment = switch alignment {
            case .leading:  .left
            case .center:   .center
            case .trailing: .right
        }
        return copy
    }

    /// Sets the text alignment using NSTextAlignment directly.
    public func textAlignment(_ alignment: NSTextAlignment) -> NumericTextField {
        var copy = self
        copy._textAlignment = alignment
        return copy
    }

    // MARK: - Body

    public var body: some View {
#if os(iOS)
        NumericFieldiOS(
            title,
            text: $numericText,
            style: style,
            font: _font,
            textAlignment: _textAlignment,
            onDone: { value in
                numericText = reformatter(value)
                onCommit()
            },
            onFocusChange: { focused in
                if !focused { numericText = reformatter(numericText) }
                onEditingChanged(focused)
            }
        )
        .onAppear { numericText = reformatter(numericText) }
#else
        TextField(title, text: $numericText,
            onEditingChanged: { exited in
                if !exited { numericText = reformatter(numericText) }
                onEditingChanged(exited)
            },
            onCommit: {
                numericText = reformatter(numericText)
                onCommit()
            }
        )
        .numericText(number: $numericText, style: style)
        .onAppear { numericText = reformatter(numericText) }
#endif
    }
}

// MARK: - Default reformatter

public func reformat(_ stringValue: String) -> String {
    let value = NumberFormatter().number(from: stringValue)
    if let v = value {
        let compare = v.compare(NSNumber(value: 0.0))
        if compare == .orderedSame { return "0" }
        if compare == .orderedAscending {
            if v.compare(NSNumber(value: -1e-3)) != .orderedDescending {
                if v.compare(NSNumber(value: -1e5)) == .orderedDescending {
                    return v.decimalStyle
                }
            }
        } else {
            if v.compare(NSNumber(value: 1e5)) == .orderedAscending {
                if v.compare(NSNumber(value: 1e-3)) != .orderedAscending {
                    return v.decimalStyle
                }
            }
            return v.scientificStyle
        }
    }
    return stringValue
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

#if os(iOS)

// MARK: - Cursor coordination notification

private extension Notification.Name {
    static let numericFieldDidBeginEditing = Notification.Name("NumericFieldDidBeginEditing")
}

// MARK: - iOS SwiftUI wrapper

private struct NumericFieldiOS: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var style: NumericStringStyle
    var font: UIFont?
    var textAlignment: NSTextAlignment
    var onDone: (String) -> Void
    var onFocusChange: (Bool) -> Void

    @ScaledMetric private var scaledSize: CGFloat = 17

    init(_ label: LocalizedStringKey,
         text: Binding<String>,
         style: NumericStringStyle = .defaultStyle,
         font: UIFont? = nil,
         textAlignment: NSTextAlignment = .natural,
         onDone: @escaping (String) -> Void = { _ in },
         onFocusChange: @escaping (Bool) -> Void = { _ in }) {
        self.label = label
        self._text = text
        self.style = style
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
                font: resolvedFont,
                style: style,
                textAlignment: textAlignment,
                onDone: onDone,
                onFocusChange: onFocusChange
            )
            .frame(height: resolvedFont.pointSize * 1.6)
        }
        .onChange(of: text) { _, newValue in
            let filtered = newValue.numericValue(style: style).uppercased()
            if filtered != newValue { text = filtered }
        }
    }
}

// MARK: - Text bridge

@Observable
private final class NumericTextBridge {
    var text: String
    var style: NumericStringStyle
    var onChange: (String) -> Void = { _ in }

    init(_ initial: String, style: NumericStringStyle) {
        self.text = initial
        self.style = style
    }
}

// MARK: - Keyboard host view

private struct KeyboardHost: View {
    var bridge: NumericTextBridge
    var onDone: (String) -> Void

    var body: some View {
        @Bindable var bridge = bridge
        ScientificKeyboardView(text: $bridge.text, style: bridge.style, onDone: onDone)
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

// MARK: - Blinking cursor view

//private class BlinkingCursorView: UIView {
//    private var observerToken: NSObjectProtocol?
//
//    override func didMoveToWindow() {
//        super.didMoveToWindow()
//        // Subscribe to begin-editing notifications from any NumericTextField.
//        // When another field gains focus, stop blinking unless it's our own field.
//        observerToken = NotificationCenter.default.addObserver(
//            forName: .numericFieldDidBeginEditing,
//            object: nil,
//            queue: .main
//        ) { [weak self] notification in
//            guard let self else { return }
//            if (notification.object as? UIView) !== self.superview {
//                self.stopBlinking()
//            }
//        }
//    }
//
//    deinit {
//        if let token = observerToken {
//            NotificationCenter.default.removeObserver(token)
//        }
//    }
//
//    func startBlinking() {
//        layer.removeAllAnimations()
//        alpha = 1
//        UIView.animate(
//            withDuration: 0.5,
//            delay: 0,
//            options: [.repeat, .autoreverse, .allowUserInteraction],
//            animations: { self.alpha = 0 }
//        )
//        // Notify all other cursor views to stop blinking.
//        // object is our superview (the UITextField) so each cursor can
//        // identify whether the notification is for itself or another field.
//        NotificationCenter.default.post(
//            name: .numericFieldDidBeginEditing,
//            object: superview
//        )
//    }
//
//    func stopBlinking() {
//        layer.removeAllAnimations()
//        alpha = 0
//    }
//
//    /// Repositions the cursor inside `field` so it sits exactly where
//    /// the next keystroke will appear, respecting alignment and current text.
//    func reposition(in field: UITextField) {
//        guard let font = field.font else { return }
//        let text = field.text ?? ""
//        let fieldWidth = field.bounds.width
//        let fieldHeight = field.bounds.height
//        guard fieldWidth > 0 else { return }
//
//        let cursorHeight = font.lineHeight * 1.1
//        let cursorY = (fieldHeight - cursorHeight) / 2
//
//        let textWidth: CGFloat = text.isEmpty
//            ? 0
//            : (text as NSString).size(withAttributes: [.font: font]).width
//
//        let cursorX: CGFloat
//        switch field.textAlignment {
//        case .right:
//            cursorX = fieldWidth
//        case .center:
//            let textStart = (fieldWidth - textWidth) / 2
//            cursorX = text.isEmpty
//                ? fieldWidth / 2
//                : min(textStart + textWidth, fieldWidth)
//        default:
//            cursorX = text.isEmpty ? 0 : min(textWidth, fieldWidth)
//        }
//
//        frame = CGRect(x: cursorX, y: cursorY, width: 2, height: cursorHeight)
//    }
//}
private class BlinkingCursorView: UIView {
	private var observerToken: NSObjectProtocol?
	weak var field: UITextField?   // set by makeUIView
	
	override func didMoveToWindow() {
		super.didMoveToWindow()
		if let token = observerToken {
			NotificationCenter.default.removeObserver(token)
			observerToken = nil
		}
		guard window != nil else { return }
		observerToken = NotificationCenter.default.addObserver(
			forName: .numericFieldDidBeginEditing,
			object: nil,
			queue: .main
		) { [weak self] notification in
			guard let self else { return }
			guard let activeField = notification.object as? UITextField else { return }
			if activeField !== self.field {
				self.stopBlinking()
			}
		}
	}
	
	deinit {
		if let token = observerToken {
			NotificationCenter.default.removeObserver(token)
		}
	}
	
	func startBlinking() {
		layer.removeAllAnimations()
		alpha = 1
		UIView.animate(
			withDuration: 0.5,
			delay: 0,
			options: [.repeat, .autoreverse, .allowUserInteraction],
			animations: { self.alpha = 0 }
		)
		// No notification here — Coordinator posts it
		print("startBlinking on cursor \(ObjectIdentifier(self))")
	}
	
	func stopBlinking() {
		layer.removeAllAnimations()
		alpha = 0
		print("stopBlinking on cursor \(ObjectIdentifier(self))")
	}
	
	/// Repositions the cursor inside `field` so it sits exactly where
	/// the next keystroke will appear, respecting alignment and current text.
	func reposition(in field: UITextField) {
		guard let font = field.font else { return }
		let text = field.text ?? ""
		let fieldWidth = field.bounds.width
		let fieldHeight = field.bounds.height
		guard fieldWidth > 0 else { return }
		
		let cursorHeight = font.lineHeight * 1.1
		let cursorY = (fieldHeight - cursorHeight) / 2
		
		let textWidth: CGFloat = text.isEmpty
		? 0
		: (text as NSString).size(withAttributes: [.font: font]).width
		
		let cursorX: CGFloat
		switch field.textAlignment {
		case .right:
			cursorX = fieldWidth
		case .center:
			let textStart = (fieldWidth - textWidth) / 2
			cursorX = text.isEmpty
			? fieldWidth / 2
			: min(textStart + textWidth, fieldWidth)
		default:
			cursorX = text.isEmpty ? 0 : min(textWidth, fieldWidth)
		}
		
		frame = CGRect(x: cursorX, y: cursorY, width: 2, height: cursorHeight)
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
    var font: UIFont
    var style: NumericStringStyle
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
		// Remove any existing cursor subviews from a previous makeUIView call
		field.subviews.filter { $0 is BlinkingCursorView }.forEach { $0.removeFromSuperview() }
        let cursor = BlinkingCursorView()
        cursor.backgroundColor = .systemBlue
        cursor.layer.cornerRadius = 1
        cursor.alpha = 0
		cursor.field = field
        field.addSubview(cursor)
        coord.cursorView = cursor

        field.onLayout = { [weak field, weak coord] in
            guard let field, let coord, field.isFirstResponder else { return }
            coord.cursorView?.reposition(in: field)
        }
		print("makeUIView creating cursor \(ObjectIdentifier(cursor)) for field \(ObjectIdentifier(field))")
		
        coord.bridge.onChange = { [weak field] newValue in
            let filtered = newValue.numericValue(style: coord.parent.style).uppercased()
            field?.text = filtered
            coord.parent.text = filtered
            if let field, field.isFirstResponder {
                coord.cursorView?.reposition(in: field)
            }
        }

        let host = UIHostingController(rootView: KeyboardHost(
            bridge: coord.bridge,
            onDone: { value in
                coord.parent.onDone(value)
                field.resignFirstResponder()
            }
        ))

        let targetHeight = host.view.systemLayoutSizeFitting(
            CGSize(width: UIScreen.main.bounds.width,
                   height: UIView.layoutFittingCompressedSize.height)
        ).height

        let container = KeyboardContainerView()
        container.preferredHeight = targetHeight
        container.translatesAutoresizingMaskIntoConstraints = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
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
		// Remove any orphaned cursor subviews that aren't the current one
		for subview in field.subviews where subview is BlinkingCursorView {
			if subview !== coord.cursorView {
				subview.removeFromSuperview()
			}
		}
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
            self.bridge = NumericTextBridge(parent.text, style: parent.style)
        }

		func textFieldDidBeginEditing(_ textField: UITextField) {
			cursorView?.reposition(in: textField)
			cursorView?.startBlinking()
			// Post after startBlinking so all OTHER cursors stop
			NotificationCenter.default.post(
				name: .numericFieldDidBeginEditing,
				object: textField   // use the field, not the cursor's superview
			)// End of post code
			parent.onFocusChange(true)
		}
		
        func textFieldDidEndEditing(_ textField: UITextField) {
            cursorView?.stopBlinking()
            parent.text = bridge.text
            parent.onFocusChange(false)
        }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool { false }
    }
}

#endif

#endif // canImport(Observation)
#endif
