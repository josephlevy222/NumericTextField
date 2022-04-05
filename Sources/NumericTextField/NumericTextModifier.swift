//NumericTextModifier.swift
import SwiftUI
/// A modifier that observes any changes to a string, and updates that string to remove any non-numeric characters.
/// It also will convert that string to a `NSNumber` for easy use.
public struct NumericTextModifier: ViewModifier {
    /// The string that the text field is bound to
    /// A number that will be updated when the `text` is updated.
    @Binding public var number: String
    /// Should the user be allowed to enter a decimal number, or an integer
    public var style = NumericStringStyle()

    /// - Parameters:
    ///   - number:: The string 'number" that this should observe and filter
    ///     style: 
    ///   - isDecimalAllowed: Should the user be allowed to enter a decimal number, or an integer
    ///   - isExponentAllowed: Should the E (or e) be allowed in number for exponent entry
    ///   - isMinusAllowed: Should negatives be allowed with minus sign (-) at start of number
    //public init( number: Binding<String>, style: style) {
    //    self._number = number
    //    self.style = style
    //}
    public func body(content: Content) -> some View {
        content
            .onChange(of: number) { newValue in
                let numeric = newValue.numericValue(style: style).uppercased()
                if newValue != numeric {
                    number = numeric
                }
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

