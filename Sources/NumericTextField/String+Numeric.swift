// String+Numeric.swift
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
}

public func validationMessage(_ string: String, style: NumericStringStyle) -> String? {
	guard let value = string.isUnderOrOverflow else { /*overflow or partial*/
		let partials = ["E", "E-", ".", ",", "-"]
		if partials.contains(where: { string.uppercased().hasSuffix($0) }) || string.isEmpty { return nil }
		return "Overflow, reduce magnitude" }
	guard !value.isNaN else { return "Underlow, 0 will replace"}
	guard !style.decimalSeparator && Int(exactly: value) == nil else { return "Integer required" }
	guard let range = style.range else { return nil }
	guard range.contains(value) else { return "Out of range: \(range)"}
	return nil
}

extension String {
	fileprivate var isUnderOrOverflow: Double? { //nil - overflow, NAN underflow, Double("self") o.w.
		let localeSep = Locale.current.decimalSeparator ?? "."
		let normalized = self.replacingOccurrences(of: localeSep, with: ".")
		guard let value = Double(normalized), value.isFinite else { return nil /*overflow*/}
		return value == 0 && (normalized.contains { $0.isNumber && $0 != "0" }) ? .nan  : value
	}
	
	/// Determines if the current string is a valid representation based on style.  Used for UI highlighting. Returns true only if it's a real, in-range number.
	public func isValid(style: NumericStringStyle) -> Bool { //validationMessage(self, style: style) == nil }
		guard let value = self.isUnderOrOverflow, !value.isNaN else { return false }
		if !style.decimalSeparator && Int(exactly: value) == nil { return false }
		return style.range?.contains(value) ?? true
	}
	
	public func numericValue(style: NumericStringStyle) -> String {
		
		let sep = Character(Locale.current.decimalSeparator ?? ".")
		var hasDecimal = false
		var hasExponent = false
		var hasDigits = false
		var minusAllowed = style.negatives
		
		func keepIf(_ condition: Bool, perform: () -> Void ) -> Bool { if condition { perform() }; return condition }
		
		let filtered = self.uppercased().filter { char in
			switch char {
			case "0"..."9": keepIf(true) {
				hasDigits = true
				minusAllowed = false
			}
			case "-": keepIf(minusAllowed) { minusAllowed = false }
				
			case sep: keepIf(style.decimalSeparator && !hasDecimal && !hasExponent) {
				hasDecimal = true
				minusAllowed = false
			}
			case "E": keepIf(style.exponent && hasDigits && !hasExponent) {
				hasExponent = true
				minusAllowed = true
			}
			default: false
			}
		}
		return String(filtered)
	}
	
	// MARK: - Default reformatter
	
	public func reformat(_ style: NumericStringStyle) -> String {
		let upper = self.uppercased()
		guard  let value = isUnderOrOverflow else { return upper } // overflow
		if value.isNaN { return "0" } 
		
		let partials = ["E", "E-", ".", ",", "-"]
		if partials.contains(where: { upper.hasSuffix($0) }) || upper.isEmpty { return self }
		
		guard var decimalValue = self.toDecimal() else { return upper }
		
		if let range = style.range {
			let doubleValue = Double(truncating: decimalValue as NSDecimalNumber)
			if !range.contains(doubleValue) {
				guard style.clampToRange else { return self }
				decimalValue = Decimal(min(max(doubleValue, range.lowerBound), range.upperBound))
			}
		}
		// Preserve red flag if integer style but value has fractional part
		if !style.decimalSeparator && !decimalValue.isWholeNumber { return self }
		
		if let threshold = style.scientificThreshold {
			let absVal = abs(decimalValue)
			if absVal >= threshold.large || (absVal > 0 && absVal <= threshold.small) {
				return decimalValue.formatted(
					.number.notation(.scientific)
					.precision(.significantDigits(threshold.significantDigits))
				)
			}
		}
		
		return decimalValue.formatted(.number.grouping(.never).precision(.significantDigits(1...20)))
	}

	// Decimal(string:locale:) handles commas vs dots automatically based on the user's region
	func toDecimal() -> Decimal? { Decimal(string: self, locale: .current) }
	
	func optionalNumber(formatter: NumberFormatter = NumberFormatter()) -> NSNumber? { formatter.number(from: self) }
	
	/// Returns the string's value as a `Double`, or `nil` if the string is not a valid number  or if the value overflows `Double`'s finite range.
	func optionalDouble(formatter: NumberFormatter = NumberFormatter()) -> Double? {
		if let decimal = toDecimal() {
			let d = NSDecimalNumber(decimal: decimal).doubleValue
			return d.isFinite ? d : nil
		}
		return optionalNumber(formatter: formatter).map { Double(truncating: $0) }
	}
	
	func toDouble(formatter: NumberFormatter = NumberFormatter()) -> Double { optionalDouble(formatter: formatter) ?? 0.0 }
	
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
	
	func toInt(formatter: NumberFormatter = NumberFormatter()) -> Int { optionalInt(formatter: formatter) ?? 0 }
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
	
	public struct ScientificThreshold {
		public var large: Decimal
		public var small: Decimal
		public var significantDigits: ClosedRange<Int>
		
		public static let `default` = ScientificThreshold(
			large: 100_000,
			small: 0.001,
			significantDigits: 1...6
		)
	}

	public var layout: NumericKeyboardLayout // Only relevant for the custom iOS touch keyboard.
	
	public init(
		decimalSeparator: Bool = true, negatives: Bool = true, exponent: Bool = true, range: ClosedRange<Double>? = nil,
		clampToRange: Bool = false, scientificThreshold: ScientificThreshold? = .default,
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
