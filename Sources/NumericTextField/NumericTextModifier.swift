//NumericTextModifier.swift
import SwiftUI
/// A modifier that observes any changes to a string, and updates that string to remove any non-numeric characters.
/// It also will convert that string to a `NSNumber` for easy use.
public struct NumericTextModifier: ViewModifier {
    /// The string that the text field is bound to
    /// A number that will be updated when the `text` is updated.
    @Binding public var number: String
    /// Should the user be allowed to enter a decimal number, or an integer, etc.
    public var style = NumericStringStyle()

    /// - Parameters:
    ///   - number:: The string 'number" that this should observe and filter
    ///   - style:: The style of number allowed/formatted 
    public func body(content: Content) -> some View {
        content
            .onChange(of: number) { newValue in
                number = newValue.numericValue(style: style).uppercased()
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

