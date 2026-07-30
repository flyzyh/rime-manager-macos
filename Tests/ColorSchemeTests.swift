import XCTest
import SwiftUI
@testable import RimeManager

final class ColorSchemeTests: XCTestCase {

    // MARK: - parseHexColor Tests

    func testParseHexColor6Digits() {
        let color = ColorScheme.parseHexColor("0xFF5733")
        XCTAssertNotNil(color)
    }

    func testParseHexColor8Digits() {
        let color = ColorScheme.parseHexColor("0x80FF5733")
        XCTAssertNotNil(color)
    }

    func testParseHexColorWithoutPrefix() {
        let color = ColorScheme.parseHexColor("FF5733")
        XCTAssertNotNil(color)
    }

    func testParseHexColorInvalid() {
        let color = ColorScheme.parseHexColor("invalid")
        XCTAssertNil(color)
    }

    func testParseHexColorEmpty() {
        let color = ColorScheme.parseHexColor("")
        XCTAssertNil(color)
    }

    // MARK: - colorToRimeHex Tests

    func testColorToRimeHex() {
        let color = Color.red
        let hex = ColorScheme.colorToRimeHex(color)

        XCTAssertTrue(hex.hasPrefix("0x"))
        // Format is 0xRRGGBB (8 chars total)
        XCTAssertGreaterThanOrEqual(hex.count, 8)
    }

    func testColorToRimeHexBlack() {
        let color = Color.black
        let hex = ColorScheme.colorToRimeHex(color)

        XCTAssertTrue(hex.lowercased().contains("000000"))
    }

    func testColorToRimeHexWhite() {
        let color = Color.white
        let hex = ColorScheme.colorToRimeHex(color)

        XCTAssertTrue(hex.lowercased().contains("ffffff"))
    }

    // MARK: - Round Trip Tests

    func testParseAndConvertRoundTrip() {
        // Test that parsing and converting produces valid hex
        let originalHex = "0xFF336699"

        guard let color = ColorScheme.parseHexColor(originalHex) else {
            XCTFail("Failed to parse hex color")
            return
        }

        let convertedHex = ColorScheme.colorToRimeHex(color)

        // Should produce valid hex format
        XCTAssertTrue(convertedHex.hasPrefix("0x"))
        // The color should be parseable again
        XCTAssertNotNil(ColorScheme.parseHexColor(convertedHex))
    }

    // MARK: - EditableColorScheme Tests

    func testEditableColorSchemeParsing() {
        let scheme = EditableColorScheme(name: "test")
        scheme.backColor = "0xFFFFFF"
        scheme.textColor = "0x000000"

        XCTAssertNotNil(scheme.parsedBackColor)
        XCTAssertNotNil(scheme.parsedTextColor)
    }

    func testEditableColorSchemeDefaultColors() {
        let scheme = EditableColorScheme(name: "test")

        // Should have default fallback colors
        XCTAssertNotNil(scheme.parsedBackColor)
        XCTAssertNotNil(scheme.parsedTextColor)
        XCTAssertNotNil(scheme.parsedHilitedBack)
    }
}
