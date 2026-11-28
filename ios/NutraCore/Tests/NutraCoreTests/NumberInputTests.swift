import XCTest
@testable import NutraCore

final class NumberInputTests: XCTestCase {
    func testDotAndCommaDecimals() {
        XCTAssertEqual(NumberInput.parse("12.5", in: NumberInput.grams), 12.5)
        XCTAssertEqual(NumberInput.parse("12,5", in: NumberInput.grams), 12.5)  // German / French keypad
        XCTAssertEqual(NumberInput.parse(" 95 ", in: NumberInput.kcal), 95)
        XCTAssertEqual(NumberInput.parse("0", in: NumberInput.kcal), 0)
    }

    func testRejectsGarbageAndOutOfRange() {
        XCTAssertNil(NumberInput.parse("", in: NumberInput.kcal))
        XCTAssertNil(NumberInput.parse("abc", in: NumberInput.kcal))
        XCTAssertNil(NumberInput.parse("1,2,3", in: NumberInput.kcal))
        XCTAssertNil(NumberInput.parse("-5", in: NumberInput.kcal))
        XCTAssertNil(NumberInput.parse("10001", in: NumberInput.kcal))
        XCTAssertNil(NumberInput.parse("99999999999999999999", in: NumberInput.kcal))  // would trap Int(_:)
        XCTAssertNil(NumberInput.parse("inf", in: 0...Double.greatestFiniteMagnitude))
        XCTAssertNil(NumberInput.parse("nan", in: 0...Double.greatestFiniteMagnitude))
    }

    func testOptionalFields() {
        XCTAssertTrue(NumberInput.isValidOptional("", in: NumberInput.grams))
        XCTAssertTrue(NumberInput.isValidOptional("  ", in: NumberInput.grams))
        XCTAssertTrue(NumberInput.isValidOptional("2,5", in: NumberInput.grams))
        XCTAssertFalse(NumberInput.isValidOptional("2..5", in: NumberInput.grams))
        XCTAssertFalse(NumberInput.isValidOptional("6000", in: NumberInput.grams))
    }
}
