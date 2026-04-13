//String+Numeric.swift
import Foundation

// String+Numeric.swift

import Foundation

extension Decimal {
	/// Checks if the decimal has no fractional component without precision loss.
	var isWholeNumber: Bool {
		if self.isZero { return true }
		var result = Decimal()
		var mutableSelf = self
		// Rounds to 0 decimal places. If result == self, it's an integer.
		NSDecimalRound(&result, &mutableSelf, 0, .plain)
		return self == result
	}
}

extension String {
	
	/// Determines if the current string is a valid representation based on style.
	public func isValid(style: NumericStringStyle) -> Bool {
		if self.isEmpty || self == "-" || self == "." || self == "," { return true }
		let upper = self.uppercased()
		
		// Allow partial scientific notation if the style allows exponents
		if upper.hasSuffix("E") || upper.hasSuffix("E-") {
			return style.exponent
		}
		
		guard let decimal = self.toDecimal() else { return false }
		
		// Flag non-integers if decimals are disabled
		if !style.decimalSeparator && !decimal.isWholeNumber { return false }
		
		// Check Range (Flag if outside, don't clamp)
		if let range = style.range {
			let dValue = (decimal as NSNumber).doubleValue
			return range.contains(dValue)
		}
		
		return true
	}
	
	public func numericValue(style: NumericStringStyle) -> String {
		let sep = Locale.current.decimalSeparator ?? "."
		var hasDecimal = false
		var hasExponent = false
		var hasDigits = false
		var filteredChars = [Character]()
		
		for char in self.uppercased() {
			let sChar = String(char)
			
			// 1. Digits
			if "0123456789".contains(char) {
				hasDigits = true
				filteredChars.append(char)
				continue
			}
			
			// 2. Negative Sign (At start or right after 'E')
			if sChar == "-"  {
				if (filteredChars.isEmpty && style.negatives) || filteredChars.last == "E" {
					filteredChars.append(char)
					continue
				}
			}
			
			// 3. Decimal Separator
			if sChar == sep && style.decimalSeparator && !hasDecimal && !hasExponent {
				hasDecimal = true
				filteredChars.append(char)
				continue
			}
			
			// 4. Exponent
			if sChar == "E" && style.exponent && hasDigits && !hasExponent {
				hasExponent = true
				filteredChars.append(char)
				continue
			}
		}
		return String(filteredChars)
	}
}

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

#if os(iOS) && !targetEnvironment(macCatalyst)
public enum NumericKeyboardLayout {
	case automatic  // Switches between Portrait/Landscape based on size class
	case portrait
	case landscape
	case compactHeight
}
#endif
public struct NumericStringStyle {
	static public var defaultStyle = NumericStringStyle()
	static public var intStyle = NumericStringStyle(decimalSeparator: false, negatives: true, exponent: false)
	
	public var decimalSeparator: Bool
	public var negatives: Bool
	public var exponent: Bool
	public var range: ClosedRange<Double>?
#if os(iOS) && !targetEnvironment(macCatalyst) /// Only relevant for the custom iOS touch keyboard
	public var layout: NumericKeyboardLayout
#endif
	
	// MARK: - iOS Initializer
#if os(iOS) && !targetEnvironment(macCatalyst)
	public init(
		decimalSeparator: Bool = true,
		negatives: Bool = true,
		exponent: Bool = true,
		range: ClosedRange<Double>? = nil,
		layout: NumericKeyboardLayout = .automatic
	) {
		self.decimalSeparator = decimalSeparator
		self.negatives = negatives
		self.exponent = exponent
		self.range = range
		self.layout = layout
	}
#else
	
	// MARK: - macOS & Catalyst Initializer
	public init(
		decimalSeparator: Bool = true,
		negatives: Bool = true,
		exponent: Bool = true,
		range: ClosedRange<Double>? = nil
	) {
		self.decimalSeparator = decimalSeparator
		self.negatives = negatives
		self.exponent = exponent
		self.range = range
	}
#endif
}

public extension String {
	
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
