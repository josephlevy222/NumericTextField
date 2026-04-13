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
		// NSDecimalNumber is the correct bridge; Decimal can exceed Double's range,
		// in which case doubleValue returns ±infinity — treat that as out-of-range.
		if let range = style.range {
			let dValue = NSDecimalNumber(decimal: decimal).doubleValue
			guard dValue.isFinite else { return false }
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

extension String {
	func toDecimal() -> Decimal? {
		// Decimal(string:locale:) handles commas vs dots automatically based on the user's region
		Decimal(string: self, locale: .current)
	}
}

public extension String {
	
	func optionalNumber(formatter: NumberFormatter = NumberFormatter()) -> NSNumber? {
		formatter.number(from: self)
	}
	
	func optionalDouble(formatter: NumberFormatter = NumberFormatter()) -> Double? {
		optionalNumber(formatter: formatter).map { Double(truncating: $0) }
	}
	
	func toDouble(formatter: NumberFormatter = NumberFormatter()) -> Double {
		optionalNumber(formatter: formatter).map { Double(truncating: $0) } ?? 0.0
	}
	
	func toInt(formatter: NumberFormatter = NumberFormatter()) -> Int {
		optionalNumber(formatter: formatter).map { Int(truncating: $0) } ?? 0
	}
}

// MARK: - Keyboard layout (iOS custom keyboard only)

#if os(iOS) && !targetEnvironment(macCatalyst)
public enum NumericKeyboardLayout {
	case automatic   // Portrait/Landscape based on size class
	case portrait
	case landscape
	case compactHeight
}
#endif

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
