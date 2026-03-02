// NumericTextField.swift
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

    // MARK: - Modifiers

    /// Sets the font using a SwiftUI.Font — same syntax as .font() on any SwiftUI view.
    /// Uses UIFont(font:) from EditableText to convert SwiftUI.Font → UIFont.
    /// If not called, defaults to a monospaced system font scaled to the current Dynamic Type size.
    public func font(_ swiftUIFont: SwiftUI.Font) -> NumericTextField {
        var copy = self
        copy._font = UIFont(font: swiftUIFont)
        return copy
    }

    /// Sets the text alignment of the input field.
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
                    .textAlignment(.right)
                    .frame(width: 200)
                    .border(.foreground, width: 1)
                    .padding()
                Text(int + " is the Int")
            }
            HStack {
                NumericTextField("Double", numericText: $double)
                    .font(.system(size: 20, weight: .light, design: .monospaced))
                    .textAlignment(.right)
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

// MARK: - iOS SwiftUI wrapper

private struct NumericFieldiOS: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var style: NumericStringStyle
    var font: UIFont?                    // nil = use @ScaledMetric default
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

    // Use caller-supplied font or fall back to Dynamic Type scaled monospaced font
    private var resolvedFont: UIFont {
        font ?? .monospacedSystemFont(ofSize: scaledSize, weight: .regular)
    }

    var body: some View {
        let placeholderAlignment: Alignment = textAlignment == .right  ? .trailing
                                            : textAlignment == .center ? .center
                                            : .leading
        ZStack(alignment: placeholderAlignment) {
            // Placeholder — visible only when empty, like a native TextField
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
// Advertises height via intrinsicContentSize to avoid TUIKeyplane constraint conflicts.

private class KeyboardContainerView: UIView {
    var preferredHeight: CGFloat = 260 {
        didSet { invalidateIntrinsicContentSize() }
    }
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

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        let coord = context.coordinator

        field.delegate = coord
        field.font = font
        field.textColor = .label
        field.textAlignment = textAlignment
        field.tintColor = .clear
        field.autocorrectionType = .no
        field.spellCheckingType = .no

        // Blinking cursor as rightView — starts hidden
        let cursor = BlinkingCursorView()
        cursor.backgroundColor = .systemBlue
        cursor.frame = CGRect(x: 0, y: 0, width: 2, height: 24)
        cursor.layer.cornerRadius = 1
        cursor.alpha = 0
        field.rightView = cursor
        field.rightViewMode = .always
        coord.cursorView = cursor

        // Bridge: filter all input through numericValue(style:)
        coord.bridge.onChange = { [weak field] newValue in
            let filtered = newValue.numericValue(style: coord.parent.style).uppercased()
            field?.text = filtered
            coord.parent.text = filtered
        }

        // Build and attach the custom keyboard
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

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text {
            field.text = text
            context.coordinator.bridge.text = text
        }
        if field.font != font { field.font = font }
        if field.textAlignment != textAlignment { field.textAlignment = textAlignment }
        context.coordinator.parent = self
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
            cursorView?.startBlinking()
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
