// NumericTextField.swift
import SwiftUI

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

    public var body: some View {
#if os(iOS)
        ScientificField(
            title,
            text: $numericText,
            style: style,
            onDone: { value in
                numericText = reformatter(value)
                onCommit()
            },
            onFocusChange: { focused in
                if !focused {
                    numericText = reformatter(numericText)
                }
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

// MARK: - Default reformatter (unchanged from original)

public func reformat(_ stringValue: String) -> String {
    let value = NumberFormatter().number(from: stringValue)
    if let v = value {
        let compare = v.compare(NSNumber(value: 0.0))
        if compare == .orderedSame {
            return String("0")
        }
        if compare == .orderedAscending {
            let compare = v.compare(NSNumber(value: -1e-3))
            if compare != .orderedDescending {
                let compare = v.compare(NSNumber(value: -1e5))
                if compare == .orderedDescending {
                    return String(v.decimalStyle)
                }
            }
        } else {
            let compare = v.compare(NSNumber(value: 1e5))
            if compare == .orderedAscending {
                let compare = v.compare(NSNumber(value: 1e-3))
                if compare != .orderedAscending {
                    return String(v.decimalStyle)
                }
            }
            return String(v.scientificStyle)
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
                    .frame(width: 200)
                    .border(.foreground, width: 1)
                    .padding()
                Text(int + " is the Int")
            }
            HStack {
                NumericTextField("Double", numericText: $double)
                    .frame(width: 200)
                    .border(.foreground, width: 1)
                    .padding()
                Text(double + " is the double")
            }
        }
    }
}
