// NumericTextField.swift
#if false
import SwiftUI

#if os(iOS)
import UIKit
import EditableText // Provides UIFont(font: SwiftUI.Font)
#endif

// MARK: - NumericTextField (Cross-Platform API)

/// A `TextField` replacement that limits user input to numbers.
/// - iOS: Uses a custom `ScientificKeyboard`.
/// - macOS / Catalyst: Uses a standard `TextField` with a numeric filter modifier.
public struct NumericTextField: View {
	public init(_ title: LocalizedStringKey,
				numericText: Binding<String>,
				isFocused: Binding<Bool> = .constant(false),
				style: NumericStringStyle = .defaultStyle,
				onEditingChanged: @escaping (Bool) -> Void = { _ in },
				onCommit: @escaping () -> Void = { },
				onNext: (() -> Void)? = nil,
				reformatter: @escaping (String) -> String = reformat) {
		self.title = title
		self._numericText = numericText
		self._isFocused = isFocused
		self.style = style
		self.onEditingChanged = onEditingChanged
		self.onCommit = onCommit
		self.onNext = onNext
		self.reformatter = reformatter
	}
	
	public let title: LocalizedStringKey
	@Binding public var numericText: String
	@Binding public var isFocused: Bool
	public var style: NumericStringStyle = .defaultStyle
	public var onEditingChanged: (Bool) -> Void
	public var onCommit: () -> Void
	public var onNext: (() -> Void)?
	public var reformatter: (String) -> String
	
	// Internal styling
	private var font: Font = .body
	private var textAlignment: TextAlignment = .leading
	
	public var body: some View {
		Group {
#if os(iOS) && !targetEnvironment(macCatalyst)
			NumericFieldiOS(
				label: title,
				text: $numericText,
				isFocused: $isFocused,
				style: style,
				font: UIFont(font: font),
				textAlignment: textAlignment.toNSTextAlignment(),
				onDone: { value in
					numericText = reformatter(value)
					onCommit()
					onNext?()
				},
				onFocusChange: { focusing in
					if !focusing { numericText = reformatter(numericText) }
					onEditingChanged(focusing)
				}
			)
#else
			// macOS and Catalyst implementation
			TextField(title, text: $numericText)
				.onChange(of: isFocused) { _, newValue in
					// Sync focus state for non-iOS platforms if needed
				}
				.onSubmit {
					numericText = reformatter(numericText)
					onCommit()
					onNext?()
				}
				.numericText(number: $numericText, style: style)
#endif
		}
		.onAppear { numericText = reformatter(numericText) }
	}
}

// MARK: - Modifiers & Extensions

extension NumericTextField {
	public func font(_ font: Font) -> Self {
		var copy = self
		copy.font = font
		return copy
	}
	
	public func textAlignment(_ alignment: TextAlignment) -> Self {
		var copy = self
		copy.textAlignment = alignment
		return copy
	}
	
	/// Bridges SwiftUI @FocusState to the NumericTextField
	public func focused<Value: Hashable>(_ binding: FocusState<Value?>.Binding, equals value: Value) -> Self {
		var copy = self
		copy._isFocused = Binding<Bool>(
			get: { binding.wrappedValue == value },
			set: { newValue in
				if newValue { binding.wrappedValue = value }
				else if binding.wrappedValue == value { binding.wrappedValue = nil }
			}
		)
		return copy
	}
}

fileprivate extension TextAlignment {
	func toNSTextAlignment() -> NSTextAlignment {
		switch self {
		case .leading: return .left
		case .center: return .center
		case .trailing: return .right
		}
	}
}

// MARK: - Default Reformatter

public func reformat(_ stringValue: String) -> String {
	guard let v = NumberFormatter().number(from: stringValue) else { return stringValue }
	let compare = v.compare(NSNumber(value: 0.0))
	if compare == .orderedSame { return "0" }
	
	let isSmall = v.doubleValue > -1e-3 && v.doubleValue < 1e-3
	let isLarge = v.doubleValue > 1e5 || v.doubleValue < -1e5
	
	return (isSmall || isLarge) ? v.scientificStyle : v.decimalStyle
}

// MARK: - iOS Private Implementation

#if os(iOS) && !targetEnvironment(macCatalyst)

private struct NumericFieldiOS: View {
	let label: LocalizedStringKey
	@Binding var text: String
	@Binding var isFocused: Bool
	var style: NumericStringStyle
	var font: UIFont
	var textAlignment: NSTextAlignment
	var onDone: (String) -> Void
	var onFocusChange: (Bool) -> Void
	
	var body: some View {
		let alignment: Alignment = textAlignment == .right ? .trailing : (textAlignment == .center ? .center : .leading)
		
		ZStack(alignment: alignment) {
			if text.isEmpty {
				Text(label)
					.font(Font(font))
					.foregroundStyle(Color(.placeholderText))
					.allowsHitTesting(false)
			}
			
			NumericUITextField(
				text: $text,
				isFocused: $isFocused,
				font: font,
				style: style,
				textAlignment: textAlignment,
				onDone: onDone,
				onFocusChange: onFocusChange
			)
		}
		.frame(height: font.lineHeight * 1.2)
	}
}

private struct NumericUITextField: UIViewRepresentable {
	@Binding var text: String
	@Binding var isFocused: Bool
	var font: UIFont
	var style: NumericStringStyle
	var textAlignment: NSTextAlignment
	var onDone: (String) -> Void
	var onFocusChange: (Bool) -> Void
	
	func makeCoordinator() -> Coordinator { Coordinator(self) }
	
	func makeUIView(context: Context) -> NumericUITextFieldView {
		let field = NumericUITextFieldView()
		let coord = context.coordinator
		coord.field = field
		
		field.delegate = coord
		field.font = font
		field.textAlignment = textAlignment
		field.tintColor = .clear // Hide system cursor
		field.autocorrectionType = .no
		
		// Setup Keyboard
		let bridge = coord.bridge
		let host = UIHostingController(rootView: KeyboardHost(bridge: bridge, onDone: { val in
			onDone(val)
			field.resignFirstResponder()
		}))
		
		host.view.backgroundColor = UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
		let container = KeyboardContainerView()
		container.addSubview(host.view)
		host.view.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			host.view.topAnchor.constraint(equalTo: container.topAnchor),
			host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
			host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
			host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
		])
		
		field.inputView = container
		field.inputAccessoryView = nil // Important to prevent height calculation hangs
		coord.hostingController = host
		
		// Cursor View
		let cursor = BlinkingCursorView()
		field.addSubview(cursor)
		coord.cursorView = cursor
		
		field.onLayout = {
			if field.isFirstResponder { cursor.reposition(in: field) }
		}
		
		return field
	}
	
	func updateUIView(_ field: NumericUITextFieldView, context: Context) {
		let coord = context.coordinator
		coord.parent = self
		
		if field.text != text {
			field.text = text
			coord.bridge.text = text
		}
		
		// Parent VC Attachment (Fixes iPad popover issues)
		if let vc = findParentViewController(of: field), let host = coord.hostingController, host.parent == nil {
			vc.addChild(host)
			host.didMove(toParent: vc)
		}
		
		// Focus synchronization
		DispatchQueue.main.async {
			if isFocused && !field.isFirstResponder {
				field.becomeFirstResponder()
			} else if !isFocused && field.isFirstResponder {
				field.resignFirstResponder()
			}
		}
		
		if field.isFirstResponder { coord.cursorView?.reposition(in: field) }
	}
	
	private func findParentViewController(of view: UIView) -> UIViewController? {
		var responder: UIResponder? = view
		while let r = responder {
			if let vc = r as? UIViewController { return vc }
			responder = r.next
		}
		return nil
	}
	
	class Coordinator: NSObject, UITextFieldDelegate {
		var parent: NumericUITextField
		let bridge: NumericTextBridge
		var cursorView: BlinkingCursorView?
		var hostingController: UIHostingController<KeyboardHost>?
		weak var field: NumericUITextFieldView?
		
		init(_ parent: NumericUITextField) {
			self.parent = parent
			self.bridge = NumericTextBridge(parent.text, style: parent.style)
		}
		
		func textFieldDidBeginEditing(_ textField: UITextField) {
			textField.reloadInputViews() // Force immediate keyboard swap
			if !parent.isFocused { parent.isFocused = true }
			cursorView?.startBlinking()
			cursorView?.reposition(in: textField)
			parent.onFocusChange(true)
		}
		
		func textFieldDidEndEditing(_ textField: UITextField) {
			if parent.isFocused { parent.isFocused = false }
			cursorView?.stopBlinking()
			parent.text = bridge.text
			parent.onFocusChange(false)
		}
	}
}

@Observable private final class NumericTextBridge {
	var text: String
	var style: NumericStringStyle
	var onChange: (String) -> Void = { _ in }
	init(_ initial: String, style: NumericStringStyle) {
		self.text = initial
		self.style = style
	}
}

private struct KeyboardHost: View {
	var bridge: NumericTextBridge
	var onDone: (String) -> Void
	var body: some View {
		@Bindable var bridge = bridge
		ScientificKeyboardView(text: $bridge.text, style: bridge.style, onDone: onDone)
	}
}

private class KeyboardContainerView: UIView {
	override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 260) }
}

private class NumericUITextFieldView: UITextField {
	var onLayout: (() -> Void)?
	override func layoutSubviews() {
		super.layoutSubviews()
		onLayout?()
	}
}

private class BlinkingCursorView: UIView {
	func startBlinking() {
		stopBlinking()
		self.alpha = 1
		let anim = CABasicAnimation(keyPath: "opacity")
		anim.fromValue = 1; anim.toValue = 0; anim.duration = 0.5
		anim.repeatCount = .infinity; anim.autoreverses = true
		anim.isRemovedOnCompletion = false
		layer.add(anim, forKey: "blink")
	}
	
	func stopBlinking() {
		layer.removeAnimation(forKey: "blink")
		self.alpha = 0
	}
	
	func reposition(in field: UITextField) {
		guard field.isFirstResponder, let font = field.font else { stopBlinking(); return }
		let text = field.text ?? ""
		let fieldWidth = field.bounds.width
		let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
		let cursorHeight = font.lineHeight * 1.1
		
		var x: CGFloat = 0
		switch field.textAlignment {
		case .right: x = text.isEmpty ? fieldWidth : max(0, fieldWidth - textWidth)
		case .center: x = (fieldWidth + textWidth) / 2
		default: x = min(textWidth, fieldWidth)
		}
		
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		frame = CGRect(x: x, y: (field.bounds.height - cursorHeight) / 2, width: 2, height: cursorHeight)
		CATransaction.commit()
	}
}

#endif
#endif
