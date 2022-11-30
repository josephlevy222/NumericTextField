import Foundation

public var decimalNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.usesSignificantDigits = true
    formatter.numberStyle = .none
    formatter.allowsFloats = true
    return formatter
}()

public var scientificFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .scientific
    formatter.allowsFloats = true
    return formatter
}()

public var integerFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .none
    formatter.allowsFloats = false
    return formatter
}()

extension NSNumber {
    public var scientificStyle: String {
        return scientificFormatter.string(from: self) ?? description
    }
    public var decimalStyle: String {
        return decimalNumberFormatter.string(from: self) ?? description
    }
    public var integerStyle: String {
        return integerFormatter.string(from: self) ?? description
    }
}

// Use
// var s: String = nsNumber.scientificStyle


public struct NumericStringStyle {
    static public var defaultStyle = NumericStringStyle() /// decimal point, negatives, and exponent allowed with infinite range
    static public var intStyle = NumericStringStyle(decimalSeparator: false, negatives: true, exponent: false, range: nil)
    static public var positiveStyle = NumericStringStyle(decimalSeparator: true, negatives: false, exponent: true, range: nil)
    public var decimalSeparator: Bool
    public var negatives: Bool
    public var exponent: Bool
    public var range: ClosedRange<Double>? = nil
    public init(decimalSeparator: Bool = true, negatives: Bool = true , exponent: Bool = true, range: ClosedRange<Double>? = nil) {
        self.decimalSeparator = decimalSeparator || exponent // exponent E (or e) implies decimal point can be used
        self.negatives = negatives
        self.exponent = exponent
        self.range = range
    }
}


/// A String and NSNumber? struct to hold a value for a future NumericTextField
/// On init converts String to NSNumber or a number (NSNumber, Double, Float or Int) to String
///  A besoin de  beaucoup travail
///
/*
public struct NumericString : Equatable {
    private var setting = false
    public static func == (lhs: NumericString, rhs: NumericString) -> Bool {
        if let l=lhs.number, let r=rhs.number { return l == r } else { return true }
    }
    
    public var string : String = "" { // String sets number
        didSet {
            string = oldValue.numericValue(style: style)
            if !setting { number = NumberFormatter().number(from: string); setting = true }
            else { setting = false }
        }
    }
    
    public var number : NSNumber? {
        //Tight loop if used so setting number does not set string automatically
        //without the use of the settingString and settingNumber flags
        willSet {
            if let n = number {
                if !setting { string = NumberFormatter().string(from: n) ?? ""; setting = true }
                else { setting = false }
            }
        }
    }
    
    public let style = NumericStringStyle.defaultStyle
    public let formatter = decimalNumberFormatter
    
    init(_ string: String, style: NumericStringStyle = .defaultStyle) {
        self.string = string.numericValue(style: style)
        number = NumberFormatter().number(from: string)
    }
    init(_ number: NSNumber, style: NumericStringStyle = .defaultStyle ) {
        string = NumberFormatter().string(from: number) ?? ""
        self.number = number
    }
    init(double number: Double, style: NumericStringStyle = .defaultStyle) {
        self.number = NSNumber(value: number)
        string = NumberFormatter().string(from: self.number!) ?? ""
    }
    init(float number: Float, style: NumericStringStyle = .defaultStyle) {
        self.number = NSNumber(value: number)
        string = NumberFormatter().string(from: self.number!) ?? ""
    }
    init(_ number: Int, style: NumericStringStyle = .intStyle) {
        self.number = NSNumber(value: number)
        string = NumberFormatter().string(from: self.number!) ?? ""
    }
}
//
*/
