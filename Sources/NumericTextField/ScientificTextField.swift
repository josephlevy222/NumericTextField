// ScientificTextField.swift
// iOS only
#if os(iOS)
import SwiftUI
import UIKit

// MARK: - Observable text bridge

@Observable
final class ScientificTextBridge {
    var text: String
    var onChange: (String) -> Void = { _ in }

    init(_ initial: String) {
        self.text = initial
    }
}

// MARK: - Hosted keyboard view

fileprivate struct HostedKeyboard: View {
    var bridge: ScientificTextBridge
    var style: NumericStringStyle
    var onDone: (String) -> Void

    var body: some View {
		@Bindable var bridge = bridge
        ScientificKeyboardView(text: $bridge.text, style: style, onDone: onDone)
            .onChange(of: bridge.text) { _, newValue in
                bridge.onChange(newValue)
            }
    }
}

// MARK: - Custom inputView container
// Advertises height via intrinsicContentSize so iOS keyboard layout
// doesn't fight with its own internal constraints.

private class KeyboardInputView: UIView {
    var preferredHeight: CGFloat = 260

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: preferredHeight)
    }
}

// MARK: - Blinking cursor view

private class BlinkingCursorView: UIView {
    func startBlinking() {
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
    }
}

// MARK: - ScientificTextField

struct ScientificTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: UIFont = .monospacedSystemFont(ofSize: 17, weight: .regular)
    var textColor: UIColor = .label
    var style: NumericStringStyle = .defaultStyle
    var onDone: (String) -> Void = { _ in }
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        let coord = context.coordinator

        field.delegate = coord
        field.placeholder = placeholder
        field.font = font
        field.textColor = textColor
        field.textAlignment = .right
        field.tintColor = .clear       // hide system cursor
        field.autocorrectionType = .no
        field.spellCheckingType = .no

        // Blinking cursor as rightView — starts hidden
        let cursor = BlinkingCursorView()
        cursor.backgroundColor = .systemBlue
        cursor.frame = CGRect(x: 0, y: 0, width: 2, height: 24)
        cursor.layer.cornerRadius = 1
        cursor.alpha = 0               // hidden until focused
        field.rightView = cursor
        field.rightViewMode = .always
        coord.cursorView = cursor

        // Wire bridge: filter input through numericValue(style:)
        coord.bridge.onChange = { [weak field] newValue in
            let filtered = newValue.numericValue(style: coord.parent.style).uppercased()
            field?.text = filtered
            coord.parent.text = filtered
        }

        // Build hosted keyboard
        let hosted = HostedKeyboard(
            bridge: coord.bridge,
            style: style,
            onDone: { value in
                coord.parent.onDone(value)
                field.resignFirstResponder()
            }
        )

        let host = UIHostingController(rootView: hosted)

        // Measure natural SwiftUI height
        let targetHeight = host.view.systemLayoutSizeFitting(
            CGSize(width: UIScreen.main.bounds.width,
                   height: UIView.layoutFittingCompressedSize.height)
        ).height

        // Wrap in KeyboardInputView so iOS uses intrinsicContentSize
        // rather than fighting with TUIKeyplane's internal constraints
        let container = KeyboardInputView()
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
        field.inputAccessoryView = UIView()  // zero-height: suppresses toolbar
        coord.hostingController = host

        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text {
            field.text = text
            context.coordinator.bridge.text = text
        }
        // Update font if ScaledMetric changed (Dynamic Type)
        if field.font != font {
            field.font = font
        }
        context.coordinator.parent = self
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ScientificTextField
        let bridge: ScientificTextBridge
        fileprivate var hostingController: UIHostingController<HostedKeyboard>?
        fileprivate var cursorView: BlinkingCursorView?

        init(_ parent: ScientificTextField) {
            self.parent = parent
            self.bridge = ScientificTextBridge(parent.text)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            cursorView?.startBlinking()
            parent.onFocusChange(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            cursorView?.stopBlinking()
            parent.text = bridge.text
            parent.onFocusChange(false)
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool { false }   // all input goes through the custom keyboard
    }
}

#endif
