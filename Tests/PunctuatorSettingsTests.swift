import XCTest
import Yams
@testable import RimeManager

@MainActor
final class PunctuatorSettingsTests: XCTestCase {

    let schemaYAML = """
    punctuator:
      half_shape:
        ",": "，"
        ".": "。"
        "/": ["/", "÷"]
    """

    func testLoadFromSchema() {
        let p = PunctuatorSettings()
        p.load(schemaYAML: schemaYAML)

        XCTAssertEqual(p.halfShape.count, 3)
        XCTAssertTrue(p.halfShape.contains { $0.key == "," && $0.commit == "，" })
        XCTAssertTrue(p.halfShape.contains { $0.key == "/" && $0.candidates == ["/", "÷"] })
    }

    func testLoadCustomHalfShapeReplacesSchemaNode() {
        // Rime 运行时语义：custom 补丁中的 half_shape 节点整体替换 schema 的
        // half_shape（映射键级替换，不做并集）。应用显示必须与运行时一致，
        // 否则会展示运行时并不存在的映射
        let customYAML = """
        patch:
          punctuator:
            half_shape:
              ".": "．"
              ";": "；"
        """
        let p = PunctuatorSettings()
        p.load(schemaYAML: schemaYAML, customYAML: customYAML)

        XCTAssertEqual(p.halfShape.count, 2)
        XCTAssertTrue(p.halfShape.contains { $0.key == "." && $0.commit == "．" })
        XCTAssertTrue(p.halfShape.contains { $0.key == ";" && $0.commit == "；" })
        XCTAssertFalse(p.halfShape.contains { $0.key == "," }, "整体替换后 schema 独有键不再生效")
    }

    func testGeneratePatchRoundTripsMergedEntries() {
        let customYAML = """
        patch:
          punctuator:
            half_shape:
              "^": "……"
              ",": "，"
              ".": "。"
        """
        let p = PunctuatorSettings()
        p.load(schemaYAML: schemaYAML, customYAML: customYAML)

        let patch = p.generatePatch()
        let half = patch["punctuator/half_shape"] as? [String: Any]

        XCTAssertEqual(half?["^"] as? String, "……", "custom 补充的键回写时不得丢失")
        XCTAssertEqual(half?[","] as? String, "，")
        XCTAssertEqual(half?["."] as? String, "。")
    }

    func testPairEntryRoundTrip() {
        let schemaYAML = """
        punctuator:
          half_shape:
            "'": {pair: ["「", "」"]}
        """
        let p = PunctuatorSettings()
        p.load(schemaYAML: schemaYAML, customYAML: "")

        let patch = p.generatePatch()
        let half = patch["punctuator/half_shape"] as? [String: Any]
        let pair = (half?["'"] as? [String: Any])?["pair"] as? [String]
        XCTAssertEqual(pair, ["「", "」"])
    }
}
