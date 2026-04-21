//
//  NumericFieldiOS.swift
//  NumericTextField
//
//  Created by Joseph Levy on 4/13/26.
//

// iOS (non-Catalyst) private implementation
#if os(iOS) && !targetEnvironment(macCatalyst)
import SwiftUI

// MARK: - Keyboard layout (iOS custom keyboard only)

public enum NumericKeyboardLayout {
	case automatic   // Portrait/Landscape/Compact based on size class
	case portrait
	case landscape
	case compactHeight
}

// MARK: - SwiftUI wrapper

struct NumericFieldiOS: View {
	let label: LocalizedStringKey
	@Binding var text: String
	var style: NumericStringStyle
	var keyboardStyle: NumericKeyboardLayout
	@Binding var isFocused: FocusState<Bool>
	var font: UIFont?
	var textAlignment: NSTextAlignment
	var onDone: (String) -> Void
	var onFocusChange: (Bool) -> Void

	@ScaledMetric private var scaledSize: CGFloat = 17

	init(_ label: LocalizedStringKey,
		 text: Binding<String>,
		 style: NumericStringStyle = .defaultStyle,
		 keyboardStyle: NumericKeyboardLayout = .automatic,
		 isFocused: Binding<FocusState<Bool>> = .constant(FocusState()),
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
	@State private var windowBounds: CGRect = UIScreen.main.bounds  // sensible default
	@State private var fieldFrame: CGRect = .zero
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
				isFocused: Binding(get: { isFocused.wrappedValue }, set: { isFocused.wrappedValue = $0  }),
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

// MARK: - Observable text bridge

@Observable
final class NumericTextBridge {
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

// MARK: - Keyboard host view

struct KeyboardHost: View {
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

// MARK: - Keyboard container (intrinsic-size UIView)

final class KeyboardContainerView: UIView {
	var preferredHeight: CGFloat = 260 {
		didSet { invalidateIntrinsicContentSize() }
	}
	override var intrinsicContentSize: CGSize {
		CGSize(width: UIView.noIntrinsicMetric, height: preferredHeight)
	}
}

// MARK: - UITextField subclass (catches layout changes)

final class NumericUITextFieldView: UITextField {
	var onLayout: (() -> Void)?
	
	override func layoutSubviews() {
		super.layoutSubviews()
		onLayout?()
	}
}

// MARK: - UIViewRepresentable bridge

struct NumericUITextField: UIViewRepresentable {
	@Binding var text: String
	@Binding var isFocused: Bool
	
	var font: UIFont
	var style: NumericStringStyle
	var keyboardStyle: NumericKeyboardLayout = .automatic
	var textAlignment: NSTextAlignment
	var onDone: (String) -> Void
	var onFocusChange: (Bool) -> Void

	func makeCoordinator() -> Coordinator { Coordinator(self) }

	func makeUIView(context: Context) -> NumericUITextFieldView {
		let field = NumericUITextFieldView()
		let coord = context.coordinator

		field.delegate          = coord
		field.font              = font
		field.textColor         = .label
		field.textAlignment     = textAlignment
		field.tintColor         = .systemBlue
		field.autocorrectionType = .no
		field.spellCheckingType  = .no
		field.addTarget(coord, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)

		field.onLayout = { [weak field, weak coord] in
			guard let field, let coord, field.isFirstResponder else { return }
			coord.textDidChange(field)
		}

		coord.bridge.onChange = { [weak field] newValue in
			let filtered = newValue.numericValue(style: coord.parent.style).uppercased()
			field?.text = filtered
			coord.parent.text = filtered
			if let field, field.isFirstResponder {
				coord.cursorView?.reposition(in: field)
			}
		}

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
			CGSize(width: host.view.preferredLayoutWidth,
				   height: UIView.layoutFittingCompressedSize.height)
		).height
		container.preferredHeight = targetHeight

		host.view.translatesAutoresizingMaskIntoConstraints = false
		host.view.backgroundColor = .systemBackground
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
		}
		if field.font != font { field.font = font }
		if field.textAlignment != textAlignment {
			field.textAlignment = textAlignment
		}
		field.textColor = text.isValid(style: style) ? .label : .systemRed
		coord.parent = self
	}

	// MARK: Coordinator

	final class Coordinator: NSObject, UITextFieldDelegate {
		var parent: NumericUITextField
		let bridge: NumericTextBridge
		var hostingController: UIHostingController<KeyboardHost>?

		init(_ parent: NumericUITextField) {
			self.parent = parent
			self.bridge = NumericTextBridge(parent.text, style: parent.style, keyboardStyle: parent.keyboardStyle)
		}

		func textFieldDidBeginEditing(_ textField: UITextField) {
			parent.isFocused = true
			parent.onFocusChange(true)
		}

		func textFieldDidEndEditing(_ textField: UITextField) {
			parent.isFocused = false
			parent.text = bridge.text
			parent.onFocusChange(false)
		}

		@objc
		func textDidChange(_ textField: UITextField) {
			let selectionStartOffset: Int
			if let selectedRange = textField.selectedTextRange {
				selectionStartOffset = textField.offset(from: textField.beginningOfDocument, to: selectedRange.start)
			} else {
				selectionStartOffset = 0
			}
			let filtered = (textField.text ?? "").numericValue(style: parent.style).uppercased()
			if textField.text != filtered {
				textField.text = filtered
				let documentEndOffset = textField.offset(from: textField.beginningOfDocument, to: textField.endOfDocument)
				let safeOffset = min(selectionStartOffset, documentEndOffset)
				if let position = textField.position(from: textField.beginningOfDocument, offset: safeOffset) {
					textField.selectedTextRange = textField.textRange(from: position, to: position)
				}
			}
			bridge.text = filtered
			parent.text = filtered
			textField.textColor = filtered.isValid(style: parent.style) ? .label : .systemRed
		}

		func textField(_ textField: UITextField,
					   shouldChangeCharactersIn range: NSRange,
					   replacementString string: String) -> Bool { true }
	}
}

// MARK: - UIView helper

extension UIView {
	var preferredLayoutWidth: CGFloat {
		if #available(iOS 26.0, *) {
			return self.window?.windowScene?.screen.bounds.width ?? 0
		} else {
			return UIScreen.main.bounds.width
		}
	}
}

#endif
