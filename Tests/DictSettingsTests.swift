import XCTest
import Yams
@testable import RimeManager

final class DictSettingsTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DictSettingsTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Load Tests

    func testLoadDictSettings() {
        let dictYAML = """
        name: rime_mint
        version: "1.0"
        import_tables:
          - cn_dicts/base
          - cn_dicts/ext
          - cn_dicts/emoji
        """

        let dictURL = tempDir.appendingPathComponent("test.dict.yaml")
        try? dictYAML.write(to: dictURL, atomically: true, encoding: .utf8)

        let settings = DictSettings()
        settings.load(from: dictURL)

        XCTAssertEqual(settings.schemaName, "rime_mint")
        XCTAssertEqual(settings.importTables.count, 3)
        XCTAssertTrue(settings.importTables.allSatisfy { $0.enabled })
    }

    func testDictDescription() {
        let dictYAML = """
        name: test
        import_tables:
          - cn_dicts/base
          - cn_dicts/emoji
          - cn_dicts/kaomoji
        """

        let dictURL = tempDir.appendingPathComponent("test.dict.yaml")
        try? dictYAML.write(to: dictURL, atomically: true, encoding: .utf8)

        let settings = DictSettings()
        settings.load(from: dictURL)

        let descriptions = settings.importTables.map { $0.description }
        XCTAssertTrue(descriptions.contains("基础词库"))
        XCTAssertTrue(descriptions.contains("Emoji"))
        XCTAssertTrue(descriptions.contains("颜文字"))
    }

    // MARK: - Generate YAML Tests

    func testGenerateYAMLWithAllEnabled() {
        let dictYAML = """
        name: test
        import_tables:
          - table_a
          - table_b
        """

        let dictURL = tempDir.appendingPathComponent("test.dict.yaml")
        try? dictYAML.write(to: dictURL, atomically: true, encoding: .utf8)

        let settings = DictSettings()
        settings.load(from: dictURL)

        let output = settings.generateYAML()

        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(output.contains("table_a"))
        XCTAssertTrue(output.contains("table_b"))
    }

    func testGenerateYAMLWithDisabled() {
        let dictYAML = """
        name: test
        import_tables:
          - table_a
          - table_b
          - table_c
        """

        let dictURL = tempDir.appendingPathComponent("test.dict.yaml")
        try? dictYAML.write(to: dictURL, atomically: true, encoding: .utf8)

        let settings = DictSettings()
        settings.load(from: dictURL)

        // Disable table_b
        if let index = settings.importTables.firstIndex(where: { $0.name == "table_b" }) {
            settings.importTables[index].enabled = false
        }

        let output = settings.generateYAML()

        XCTAssertTrue(output.contains("table_a"))
        XCTAssertFalse(output.contains("table_b"))
        XCTAssertTrue(output.contains("table_c"))
    }

    func testGenerateYAMLPreservesCommentsAndDictionaryEntries() {
        // 带注释 + `...` 之后的词条正文（第二个 YAML 文档内容），
        // 重写时必须原样保留，不能像整体 dump 那样丢弃
        let dictYAML = """
        # 词典配置注释
        name: test
        version: "1.0"
        import_tables:
          - table_a
          - table_b
        ...

        table_a\t1
        table_b\t2
        """

        let dictURL = tempDir.appendingPathComponent("test.dict.yaml")
        try? dictYAML.write(to: dictURL, atomically: true, encoding: .utf8)

        let settings = DictSettings()
        settings.load(from: dictURL)

        if let index = settings.importTables.firstIndex(where: { $0.name == "table_a" }) {
            settings.importTables[index].enabled = false
        }

        let output = settings.generateYAML()

        XCTAssertTrue(output.contains("# 词典配置注释"))
        XCTAssertTrue(output.contains("..."))
        XCTAssertTrue(output.contains("table_a\t1"))
        XCTAssertTrue(output.contains("table_b\t2"))
        XCTAssertFalse(output.contains("- table_a"))
        XCTAssertTrue(output.contains("- table_b"))
    }

    func testGenerateYAMLWhenImportTablesMissing() {
        let dictYAML = """
        name: test
        version: "1.0"
        """

        let dictURL = tempDir.appendingPathComponent("test.dict.yaml")
        try? dictYAML.write(to: dictURL, atomically: true, encoding: .utf8)

        let settings = DictSettings()
        settings.load(from: dictURL)
        settings.importTables = [
            .init(name: "new_table", enabled: true, description: "新增")
        ]

        let output = settings.generateYAML()
        XCTAssertTrue(output.contains("import_tables"))
        XCTAssertTrue(output.contains("new_table"))
        XCTAssertTrue(output.contains("version"))
    }

    // MARK: - Toggle Tests

    func testToggleDictEntry() {
        let dictYAML = """
        name: test
        import_tables:
          - table_a
        """

        let dictURL = tempDir.appendingPathComponent("test.dict.yaml")
        try? dictYAML.write(to: dictURL, atomically: true, encoding: .utf8)

        let settings = DictSettings()
        settings.load(from: dictURL)

        XCTAssertTrue(settings.importTables[0].enabled)

        settings.importTables[0].enabled = false
        XCTAssertFalse(settings.importTables[0].enabled)
    }
}
