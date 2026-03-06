// NumericTextField.swift
#if false 
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
                isFocused: Binding<Bool> = .constant(false),
                onEditingChanged: @escaping (Bool) -> Void = { _ in },
                onCommit: @escaping () -> Void = { },
                onNext: (() -> Void)? = nil,
                reformatter: @escaping (String) -> String = reformat) {
        self._numericText = numericText
        self.title = title
        self.style = style
        self._isFocused = isFocused
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
        self.onNext = onNext
        self.reformatter = reformatter
    }

    public let title: LocalizedStringKey
    @Binding public var numericText: String
    public var style: NumericStringStyle = .defaultStyle
    @Binding public var isFocused: Bool
    public var onEditingChanged: (Bool) -> Void = { _ in }
    public var onCommit: () -> Void = { }
    public var onNext: (() -> Void)? = nil
    public var reformatter: (_ stringValue: String) -> String = reformat

    // Font storage is platform-specific:
    // iOS/Mac Catalyst: UITextField requires UIFont.
    // macOS: SwiftUI TextField takes SwiftUI.Font via .font() modifier.
#if os(iOS)
    private var _font: UIFont? = nil
#else
    private var _font: SwiftUI.Font? = nil
#endif
    private var _textAlignment: NSTextAlignment = .natural

    // MARK: - Font modifiers

#if os(iOS)
    /// Sets the font using a SwiftUI.Font — converted to UIFont via EditableText.
    public func font(_ font: SwiftUI.Font) -> NumericTextField {
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
            isFocused: $isFocused,
            font: _font,
            textAlignment: _textAlignment,
            onDone: { value in
                numericText = reformatter(value)
                onCommit()
                onNext?()
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
                onNext?()
            }
        )
        .numericText(number: $numericText, style: style)
        .onAppear { numericText = reformatter(numericText) }
        .if(_font != nil) { $0.font(_font!) }
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

#if os(iOS) && !targetEnvironment(macCatalyst)

// MARK: - iOS SwiftUI wrapper

private struct NumericFieldiOS: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var style: NumericStringStyle
    @Binding var isFocused: Bool
    var font: UIFont?
    var textAlignment: NSTextAlignment
    var onDone: (String) -> Void
    var onFocusChange: (Bool) -> Void

    @ScaledMetric private var scaledSize: CGFloat = 17

    init(_ label: LocalizedStringKey,
         text: Binding<String>,
         style: NumericStringStyle = .defaultStyle,
         isFocused: Binding<Bool> = .constant(false),
         font: UIFont? = nil,
         textAlignment: NSTextAlignment = .natural,
         onDone: @escaping (String) -> Void = { _ in },
         onFocusChange: @escaping (Bool) -> Void = { _ in }) {
        self.label = label
        self._text = text
        self.style = style
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

    /// Repositions the cursor inside `field` so it sits exactly where
    /// the next keystroke will appear, respecting alignment and current text.
    func reposition(in field: UITextField) {
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

        // Drive UIKit focus from SwiftUI isFocused binding
        if isFocused && !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isFocused && field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
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
            parent.isFocused = true
            cursorView?.reposition(in: textField)
            cursorView?.startBlinking()
            parent.onFocusChange(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFocused = false
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
#endif
