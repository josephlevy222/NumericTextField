//String+Numeric.swift
import Foundation

public extension String {
    /// Get the numeric only value from the string
    /// - Parameter style: NumericStringStyle
    /// - Returns: Only numeric characters and optionally a single decimal character and optional an E followed by numeric characters.
    ///            If non-numeric values were interspersed `1a2b` then the result will be `12`.
    ///            The numeric characters returned may not be valid numbers so conversions will generally be optional strings.

    func numericValue(style: NumericStringStyle = NumericStringStyle()) -> String {
        var hasFoundDecimal = false
        var allowMinusSign = style.negatives // - can only be first char or first char after E (or e)
        var hasFoundExponent = !style.exponent
        var allowFindingExponent = false // initially false to avoid E as first character and then to prevent finding 2nd E
        let retValue = self.filter {
            if allowMinusSign && "-".contains($0) {
                return true
            } else {
                allowMinusSign = false
                if $0.isWholeNumber {
                    allowFindingExponent = true
                  return true
                } else if style.decimalSeparator && String($0) == (Locale.current.decimalSeparator ?? ".") {
                  defer { hasFoundDecimal = true }
                  return !hasFoundDecimal
                } else if style.exponent && !hasFoundExponent && allowFindingExponent && "eE".contains($0) {
                  allowMinusSign = true
                  hasFoundDecimal = true
                  allowFindingExponent = false
                  hasFoundExponent = true
                  return true
               }
            }
            return false
        }
        
        if let rV = Double(retValue), let r = style.range {
            if rV < r.lowerBound { return String(format: "%g", r.lowerBound)}
            if rV > r.upperBound { return String(format:"%g", r.upperBound)}
        }
        return retValue
    }

    func optionalNumber(formatter: NumberFormatter = NumberFormatter()) -> NSNumber? {
        formatter.number(from: self)
    }
    
    func optionalDouble(formatter: NumberFormatter = NumberFormatter()) -> Double? {
        if let value = optionalNumber(formatter: formatter) {
            return Double(truncating: value) } else { return nil }
    }
    
    func toDouble(formatter: NumberFormatter = NumberFormatter()) -> Double {
        if let value = optionalNumber(formatter: formatter) {
            return Double(truncating: value) } else { return 0.0 }
    }
    
    func toInt(formatter: NumberFormatter = NumberFormatter()) -> Int {
       if let value = optionalNumber(formatter: formatter) {
           return Int(truncating: value) } else { return 0 }
    }
}
 

