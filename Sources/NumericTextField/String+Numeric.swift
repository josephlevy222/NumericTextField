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
		
		// For integer-only style, also validate that the value fits within Int's range.
		// Compare Decimal directly to avoid Double overflow / precision loss.
		if !style.decimalSeparator && (decimal < Decimal(Int.min) || decimal > Decimal(Int.max)) { return false }
		
		// NEW: if integer-only and range is set, require the Int value to be inside the range.
		if !style.decimalSeparator, let range = style.range {
			// decimal is already known whole + within Int bounds at this point, so this is safe.
			let intValue = NSDecimalNumber(decimal: decimal).intValue
			let dValue = Double(intValue)
			return range.contains(dValue)
		}
		
		// Existing Double/range logic (covers decimalSeparator == true, or any style where you want range enforced via Double)
		if let range = style.range {
			let dValue = NSDecimalNumber(decimal: decimal).doubleValue
			guard dValue.isFinite else { return false }
			
			// If a range is provided, also require the Double to be within that range.
			if let range = style.range {
				return range.contains(dValue)
			}
			
			return true
		} else {
			// Integer-only: must be whole, and must fit in Int exactly.
			guard decimal.isWholeNumber else { return false }
			return decimal >= Decimal(Int.min) && decimal <= Decimal(Int.max)
		}
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

	func toDecimal() -> Decimal? {
		// Decimal(string:locale:) handles commas vs dots automatically based on the user's region
		Decimal(string: self, locale: .current)
	}
	
	func optionalNumber(formatter: NumberFormatter = NumberFormatter()) -> NSNumber? {
		formatter.number(from: self)
	}
	
	/// Returns the string's value as a `Double`, or `nil` if the string is not a valid number
	/// or if the value overflows `Double`'s finite range.
	func optionalDouble(formatter: NumberFormatter = NumberFormatter()) -> Double? {
		if let decimal = toDecimal() {
			let d = NSDecimalNumber(decimal: decimal).doubleValue
			return d.isFinite ? d : nil
		}
		return optionalNumber(formatter: formatter).map { Double(truncating: $0) }
	}
	
	func toDouble(formatter: NumberFormatter = NumberFormatter()) -> Double {
		optionalDouble(formatter: formatter) ?? 0.0
	}
	
	/// Returns the string's value as an `Int`, or `nil` if the string is not a valid whole number or if the value overflows `Int`'s range.
	func optionalInt(formatter: NumberFormatter = NumberFormatter()) -> Int? {
		if let decimal = toDecimal() {
			guard decimal.isWholeNumber else { return nil }
			let d = NSDecimalNumber(decimal: decimal).doubleValue
			guard d.isFinite, d >= Double(Int.min), d <= Double(Int.max) else { return nil }
			return Int(d)
		}
		return optionalNumber(formatter: formatter).map { Int(truncating: $0) }
	}
	
	func toInt(formatter: NumberFormatter = NumberFormatter()) -> Int {
		optionalInt(formatter: formatter) ?? 0
	}
}

// MARK: - NumericStringStyle

public struct NumericStringStyle {
	static public var defaultStyle = NumericStringStyle()
	static public var intStyle = NumericStringStyle(decimalSeparator: false, negatives: true, exponent: false)
	
	public var decimalSeparator: Bool
	public var negatives: Bool
	public var exponent: Bool
	public var range: ClosedRange<Double>?
#if os(iOS) && !targetEnvironment(macCatalyst)
	/// Only relevant for the custom iOS touch keyboard.
	public var layout: NumericKeyboardLayout
	
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
