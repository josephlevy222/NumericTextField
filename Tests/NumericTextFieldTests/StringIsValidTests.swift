import XCTest
@testable import NumericTextField

final class StringIsValidTests: XCTestCase {

    private let intStyle = NumericStringStyle(decimalSeparator: false, negatives: true, exponent: false)

    // MARK: - Integer-only style: partial / empty inputs remain valid

    func testEmptyStringIsValid() {
        XCTAssertTrue("".isValid(style: intStyle))
    }

    func testNegativeSignAloneIsValid() {
        XCTAssertTrue("-".isValid(style: intStyle))
    }

    // MARK: - Integer-only style: normal in-range values are valid

    func testZeroIsValid() {
        XCTAssertTrue("0".isValid(style: intStyle))
    }

    func testPositiveInRangeIsValid() {
        XCTAssertTrue("42".isValid(style: intStyle))
    }

    func testNegativeInRangeIsValid() {
        XCTAssertTrue("-42".isValid(style: intStyle))
    }

    func testIntMaxIsValid() {
        XCTAssertTrue(String(Int.max).isValid(style: intStyle))
    }

    func testIntMinIsValid() {
        XCTAssertTrue(String(Int.min).isValid(style: intStyle))
    }

    // MARK: - Integer-only style: out-of-Int-range whole numbers are invalid

    func testLargePositiveWholeNumberIsInvalid() {
        XCTAssertFalse("999999999999999999999999999999".isValid(style: intStyle))
    }

    func testLargeNegativeWholeNumberIsInvalid() {
        XCTAssertFalse("-999999999999999999999999999999".isValid(style: intStyle))
    }

    func testJustAboveIntMaxIsInvalid() {
        // Appending a zero makes the value ~10× larger than Int.max
        let valueExceedingIntMax = String(Int.max) + "0"
        XCTAssertFalse(valueExceedingIntMax.isValid(style: intStyle))
    }

    // MARK: - Integer-only style: fractional values are still invalid

    func testFractionalValueIsInvalid() {
        XCTAssertFalse("3.14".isValid(style: intStyle))
    }

    // MARK: - Decimal style: large whole number remains valid (no Int constraint)

    func testLargeWholeNumberWithDecimalStyleIsValid() {
        let decimalStyle = NumericStringStyle(decimalSeparator: true, negatives: true, exponent: false)
        XCTAssertTrue("999999999999999999999999999999".isValid(style: decimalStyle))
    }
}
