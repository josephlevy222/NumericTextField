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

	/// Determines if the current string is a valid representation based on style.  Used for UI highlighting. Returns true only if it's a real, in-range number.
	public func isValid(style: NumericStringStyle) -> Bool {
		let localeSep = Locale.current.decimalSeparator ?? "."
		let normalized = self.replacingOccurrences(of: localeSep, with: ".")
		
		guard let value = Double(normalized), value.isFinite // Basic double check,Infinity and NaN check
		else { return false }
		
		if value == 0 { // Filter out signs and separators to see if there are any non-zero digits
			let hasNonZeroDigits = normalized.contains { $0.isNumber && $0 != "0" }
			if  hasNonZeroDigits { return false } // This was something like 1E-400
		}
		
		guard style.decimalSeparator || Int(exactly: value) != nil  /*Integer check*/ else { return false }
		
		return style.range?.contains(value) ?? true // Range check
	}
	
	public func numericValue(style: NumericStringStyle) -> String {
		
		let sep = Character(Locale.current.decimalSeparator ?? ".")
		var hasDecimal = false
		var hasExponent = false
		var hasDigits = false
		var minusAllowed = style.negatives
		
		func keepIf(_ condition: Bool, perform: () -> Void ) -> Bool {
			if condition { perform() }
			return condition
		}
		
		let filtered = self.uppercased().filter { char in
			switch char {
			case "0"..."9":
				keepIf(true) {
					hasDigits = true
					minusAllowed = false
				}
			case "-":
				keepIf(minusAllowed) { minusAllowed = false }
			case sep:
				keepIf(style.decimalSeparator && !hasDecimal && !hasExponent) {
					hasDecimal = true
					minusAllowed = false
				}
			case "E":
				keepIf(style.exponent && hasDigits && !hasExponent) {
					hasExponent = true
					minusAllowed = true
				}
			default:
				false
			}
		}
		return String(filtered)
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
