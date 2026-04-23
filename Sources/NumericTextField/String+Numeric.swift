// String+Numeric.swift
// NumericTextField
import Foundation

extension Decimal {
	// Checks if the decimal has no fractional component without precision loss.
	var isWholeNumber: Bool {
		if self.isZero { return true }
		var result = Decimal()
		var mutableSelf = self
		// Rounds to 0 decimal places. If result == self, it's an integer.
		NSDecimalRound(&result, &mutableSelf, 0, .plain)
		return self == result
	}
	
	// Checks if the value can safely be converted to a 64-bit Integer
	var fitsInInt: Bool {
		let minInt = Decimal(Int.min)
		let maxInt = Decimal(Int.max)
		return self >= minInt && self <= maxInt && self.isWholeNumber
	}
}

public struct ScientificThreshold {
	public var large: Double
	public var small: Double
	public var significantDigits: Int
	public static let `default` = ScientificThreshold(large: 1_000_000, small: 0.0001, significantDigits: 6)
}

// MARK: - NumericStringStyle

public struct NumericStringStyle {
	static public var defaultStyle = NumericStringStyle()
	static public var intStyle = NumericStringStyle(decimalSeparator: false, negatives: true, exponent: false)
	public var decimalSeparator: Bool
	public var negatives: Bool
	public var exponent: Bool
	public var range: ClosedRange<Double>?
	public var clampToRange: Bool
	public var scientificThreshold: ScientificThreshold?
	public var layout: NumericKeyboardLayout // Only relevant for the custom iOS touch keyboard.
	
	public init(
		decimalSeparator: Bool = true, negatives: Bool = true, exponent: Bool = true, range: ClosedRange<Double>? = nil,
		clampToRange: Bool = false, scientificThreshold: ScientificThreshold? = .default, //format: String = "%.g",
		layout: NumericKeyboardLayout = .automatic
	) {
		self.decimalSeparator = decimalSeparator
		self.negatives = negatives
		self.exponent = exponent
		self.range = range
		self.clampToRange = clampToRange
		self.scientificThreshold = exponent ? scientificThreshold : nil /// makes no sense without exponent
		self.layout = layout
	}
}


public func validationMessage(_ string: String, style: NumericStringStyle) -> String? {
	guard let value = string.evaluatedValue else {
		return string.isPartialNumericInput ? nil : "Overflow: Reduce magnitude"
	}
	guard !value.isNaN else { return "Underflow: Value is too small:\nWill be replaced with 0" }
	
	if !style.decimalSeparator {
		let isInteger = Int(string) != nil || Int(exactly: value) != nil
		if !isInteger {
			if let decimal = Decimal(string: string), decimal.isWholeNumber {
				// it's a whole number but doesn't fit in Int
				if !decimal.fitsInInt { return "Out of range for integer" }
			}
			else { return "Integer required" }
		}
	}
	
	if let range = style.range, !range.contains(value) {
		return "Out of range: \(range.lowerBound) to \(range.upperBound)"
	}
	return nil
}

extension String {
	/// Internal helper to ensure we always use "." for internal math with E capitalized
	private var normalized: String {
		let sep = Locale.current.decimalSeparator ?? "."
		return self.replacingOccurrences(of: sep, with: ".").uppercased()
	}
	
	/// Centralized math check: nil = Overflow, .nan = Underflow, Double = Success
	var evaluatedValue: Double? {
		let text = normalized
		guard let value = Double(text), value.isFinite else { return nil /*overflow*/}
		return value == 0 && (text.contains { $0.isNumber && $0 != "0" }) ? .nan  : value
	}
	
	var isPartialNumericInput: Bool {
		isEmpty
		|| ["E", "E-", "E+", "-"].contains(where: hasSuffix)
		|| hasSuffix(Locale.current.decimalSeparator ?? ".") && !dropLast().contains(where: \.isNumber)
	}
	
	/// Determines if the current string is a valid representation based on style.  Used for UI highlighting. Returns true only if it's a real, in-range number or partial.
	public func isValid(style: NumericStringStyle) -> Bool {
		isPartialNumericInput ? false : validationMessage(self, style: style) == nil
	}
	
	public func numericValue(style: NumericStringStyle) -> String {
		let sep = Character(Locale.current.decimalSeparator ?? ".")
		var hasDecimal = false
		var hasExponent = false
		var hasDigits = false
		var minusAllowed = style.negatives
		
		func keepIf(_ condition: Bool, perform: () -> Void ) -> Bool { if condition { perform() }; return condition }
		
		return String(uppercased().filter { char in
			switch char {
			case "0"..."9": keepIf(true) { hasDigits = true; minusAllowed = false }
			case "-": 	keepIf(minusAllowed) { minusAllowed = false }
			case sep: 	keepIf(style.decimalSeparator && !hasDecimal && !hasExponent) { hasDecimal=true; minusAllowed=false }
			case "E": 	keepIf(style.exponent && hasDigits && !hasExponent) { hasExponent = true; minusAllowed = true }
			default: 	false
			}
		})
	}
	
	// MARK: - Default reformatter
	
	public func reformat(_ style: NumericStringStyle) -> String {
		if self.isPartialNumericInput { return self }
		guard var value = evaluatedValue else { return uppercased() }
		if value.isNaN {  return "0".reformat(style)}
		
		if let range = style.range {
			if !range.contains(value) {
				guard style.clampToRange else { return self }
				value = (min(max(value, range.lowerBound), range.upperBound))
			}
		}
		
		if !style.decimalSeparator {
			guard Int(exactly: value) != nil else { return self }
			let intValue: Int
			if let parsed = Int(self), Double(parsed) == value {
				intValue = parsed          // original string, full 64-bit precision
			} else {
				intValue = Int(value)      // was clamped to a range bound, use Double value
			}
			return intValue.formatted(.number.grouping(.never))
		}
		
		let absVal = abs(value)
		let threshold = style.scientificThreshold
		let useScientific = threshold.map { absVal >= $0.large || (absVal > 0 && absVal < $0.small) } ?? false
		let sigDigits = threshold.map { 1...$0.significantDigits } ?? (1...20)
		let formatStyle: FloatingPointFormatStyle<Double> = useScientific
			? .number.notation(.scientific) : .number.grouping(.never)
		return value.formatted(formatStyle.precision(.significantDigits(sigDigits)))
	}
}
