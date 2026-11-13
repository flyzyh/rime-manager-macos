import XCTest
import Yams
@testable import RimeManager

final class SchemaSettingsTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaSettingsTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Schema Scanning Tests

    func testScanSchemasFindsFiles() {
        // Create test schema files
        let schema1 = """
        schema:
          schema_id: test_pinyin
          name: 测试拼音
        """
        let schema2 = """
        schema:
          schema_id: test_wubi
          name: 测试五笔
        """

        try? schema1.write(to: tempDir.appendingPathComponent("test_pinyin.schema.yaml"), atomically: true, encoding: .utf8)
        try? schema2.write(to: tempDir.appendingPathComponent("test_wubi.schema.yaml"), atomically: true, encoding: .utf8)

        let settings = SchemaSettings()
        settings.scanSchemas(in: tempDir)

        // Squirrel SharedSupport 的内置方案也会出现在列表中，这里只验证本地 fixture。
        XCTAssertTrue(settings.availableSchemas.contains { $0.id == "test_pinyin" })
        XCTAssertTrue(settings.availableSchemas.contains { $0.id == "test_wubi" })
    }

    func testSchemaCategoryDetection() {
        XCTAssertEqual(SchemaSettings.SchemaCategory.detect(from: "double_pinyin"), .doublePinyin)
        XCTAssertEqual(SchemaSettings.SchemaCategory.detect(from: "flypy"), .doublePinyin)
        XCTAssertEqual(SchemaSettings.SchemaCategory.detect(from: "wubi86"), .wubi)
        XCTAssertEqual(SchemaSettings.SchemaCategory.detect(from: "stroke"), .stroke)
        XCTAssertEqual(SchemaSettings.SchemaCategory.detect(from: "melt_eng"), .english)
        XCTAssertEqual(SchemaSettings.SchemaCategory.detect(from: "rime_mint"), .pinyin)
        XCTAssertEqual(SchemaSettings.SchemaCategory.detect(from: "unknown"), .other)
    }

    // MARK: - Toggle Tests

    func testToggleSchema() {
        let settings = SchemaSettings()
        settings.availableSchemas = [
            .init(id: "schema1", name: "Schema 1", file: "s1.yaml", category: .pinyin),
            .init(id: "schema2", name: "Schema 2", file: "s2.yaml", category: .wubi)
        ]
        settings.enabledSchemaIDs = ["schema1", "schema2"]

        settings.toggleSchema("schema1")
        XCTAssertFalse(settings.enabledSchemaIDs.contains("schema1"))

        settings.toggleSchema("schema1")
        XCTAssertTrue(settings.enabledSchemaIDs.contains("schema1"))
    }

    func testSetDefault() {
        let settings = SchemaSettings()
        settings.defaultSchemaID = "schema1"

        settings.setDefault("schema2")
        XCTAssertEqual(settings.defaultSchemaID, "schema2")
    }

    // MARK: - Schema List Patch Tests

    func testSchemaListPatch() {
        let settings = SchemaSettings()
        settings.enabledSchemaIDs = ["schema_a", "schema_b", "schema_c"]

        let patch = settings.schemaListPatch()

        XCTAssertNotNil(patch["schema_list"])
        let list = patch["schema_list"] as? [[String: String]]
        XCTAssertEqual(list?.count, 3)
    }

    func testSchemaListPatchDefaultFirstAndOrderPreserved() throws {
        // default.custom.yaml 中 schema_list 顺序：wubi 在前、pinyin 在后
        let customYAML = """
        patch:
          schema_list:
            - schema: test_wubi
            - schema: test_pinyin
            - schema: test_english
        """
        try customYAML.write(to: tempDir.appendingPathComponent("default.custom.yaml"), atomically: true, encoding: .utf8)

        let schemaFile = """
        schema:
          schema_id: test_pinyin
          name: 测试拼音
        """
        try schemaFile.write(to: tempDir.appendingPathComponent("test_pinyin.schema.yaml"), atomically: true, encoding: .utf8)

        let settings = SchemaSettings()
        settings.scanSchemas(in: tempDir)

        // 用户把 test_english 设为默认 → 必须排第一，其余保持原始顺序
        settings.setDefault("test_english")

        let patch = settings.schemaListPatch()
        let list = try XCTUnwrap(patch["schema_list"] as? [[String: String]])
        let ids = list.map { $0["schema"]! }
        XCTAssertEqual(ids, ["test_english", "test_wubi", "test_pinyin"])
    }

    // MARK: - isDefault Tests

    func testIsDefault() {
        let settings = SchemaSettings()
        settings.availableSchemas = [
            .init(id: "first", name: "First", file: "f.yaml", category: .pinyin)
        ]
        settings.defaultSchemaID = "first"

        XCTAssertTrue(settings.isDefault("first"))
        XCTAssertFalse(settings.isDefault("other"))
    }

    func testIsDefaultFallbackToFirst() {
        let settings = SchemaSettings()
        settings.availableSchemas = [
            .init(id: "first", name: "First", file: "f.yaml", category: .pinyin)
        ]
        settings.defaultSchemaID = ""

        XCTAssertTrue(settings.isDefault("first"))
    }
}
