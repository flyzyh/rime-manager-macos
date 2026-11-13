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

    // MARK: - Rime Color Integer Conversion

    func testRimeIntToHexSixDigitStaysOpaque() {
        // 6 位以内的颜色值补零成 8 位会把高字节 00 当作 alpha=0（全透明）
        XCTAssertEqual(SchemaAnalyzer.rimeIntToHex(0xFF5733), "FF5733")
        XCTAssertEqual(SchemaAnalyzer.rimeIntToHex(0xFFFFFF), "FFFFFF")
        XCTAssertEqual(SchemaAnalyzer.rimeIntToHex(0), "000000")
    }

    func testRimeIntToHexEightDigitKeepsAlpha() {
        // 0xAABBGGRR：Rime 的字节序与常见 RGB 相反，8 位值保留 alpha 字节
        XCTAssertEqual(SchemaAnalyzer.rimeIntToHex(0x80FF5733), "80FF5733")
        XCTAssertEqual(SchemaAnalyzer.rimeIntToHex(0xFFFF840A), "FFFF840A")
    }

    func testParseColorFromIntValue() {
        // YAML 中 0xFF5733 会被解析为 Int，parseColor 需按 6 位不透明处理
        let color = SchemaAnalyzer.parseColor(0xFF5733)
        XCTAssertNotNil(color)

        // 非法值返回 nil
        XCTAssertNil(SchemaAnalyzer.parseColor("bogus color" as Any?))
        XCTAssertNil(SchemaAnalyzer.parseColor(nil))
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
