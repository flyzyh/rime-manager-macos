import XCTest
@testable import RimeManager

final class FileManagerServiceTests: XCTestCase {

    var tempDir: URL!
    var service: FileManagerService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileManagerServiceTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = FileManagerService()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - File Read/Write Tests

    func testWriteAndReadFile() throws {
        let testContent = "Hello, Rime!"
        let fileURL = tempDir.appendingPathComponent("test.txt")

        try service.writeFileContent(testContent, to: fileURL, shouldBackup: false)

        let readContent = service.readFileContent(at: fileURL)
        XCTAssertEqual(readContent, testContent)
    }

    func testWriteWithBackup() throws {
        let testContent = "Content with backup"
        let fileURL = tempDir.appendingPathComponent("backup_test.txt")

        // Write initial content
        try service.writeFileContent("Initial", to: fileURL, shouldBackup: false)

        // Write with backup
        try service.writeFileContent(testContent, to: fileURL, shouldBackup: true)

        // Verify content was written
        let readContent = service.readFileContent(at: fileURL)
        XCTAssertEqual(readContent, testContent)

        // Check that a backup directory was created (backup_YYYYMMDD_HHMMSS format)
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let backupDirs = contents.filter { $0.lastPathComponent.hasPrefix("backup_") }
        XCTAssertFalse(backupDirs.isEmpty, "Backup directory should exist")
    }

    func testReadNonExistentFile() {
        let fileURL = tempDir.appendingPathComponent("nonexistent.txt")
        let content = service.readFileContent(at: fileURL)
        XCTAssertTrue(content.isEmpty)
    }

    func testReadGB18030EncodedFile() throws {
        // GBK/GB18030 编码的词库文件应能读出中文，而不是返回空串
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        let fileURL = tempDir.appendingPathComponent("gbk_dict.txt")
        let content = "你好世界"
        try content.data(using: gb18030)!.write(to: fileURL)

        XCTAssertEqual(service.readFileContent(at: fileURL), content)
    }

    // MARK: - File Exists Tests

    func testFileExists() throws {
        let fileURL = tempDir.appendingPathComponent("exists.txt")
        try "test".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertTrue(service.fileExists(at: fileURL))
    }

    func testFileNotExists() {
        let fileURL = tempDir.appendingPathComponent("not_exists.txt")
        XCTAssertFalse(service.fileExists(at: fileURL))
    }

    // MARK: - Directory Scanning Tests

    func testScanDirectory() throws {
        // Create some files
        try "a".write(to: tempDir.appendingPathComponent("file1.yaml"), atomically: true, encoding: .utf8)
        try "b".write(to: tempDir.appendingPathComponent("file2.yaml"), atomically: true, encoding: .utf8)
        try "c".write(to: tempDir.appendingPathComponent("file3.txt"), atomically: true, encoding: .utf8)

        let files = service.scanDirectory(tempDir)

        XCTAssertEqual(files.count, 3)
    }

    func testScanEmptyDirectory() throws {
        let emptyDir = tempDir.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let files = service.scanDirectory(emptyDir)

        XCTAssertTrue(files.isEmpty)
    }

    // MARK: - Backup Tests

    func testCreateFullBackup() throws {
        // Create some files to backup
        try "content1".write(to: tempDir.appendingPathComponent("config1.yaml"), atomically: true, encoding: .utf8)
        try "content2".write(to: tempDir.appendingPathComponent("config2.yaml"), atomically: true, encoding: .utf8)

        let backupURL = service.createFullBackup(of: tempDir)

        XCTAssertNotNil(backupURL)
        if let url = backupURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertTrue(url.lastPathComponent.hasPrefix("backup_"))
        }
    }

    // MARK: - Export Tests

    func testExportFile() throws {
        let sourceURL = tempDir.appendingPathComponent("source.yaml")
        try "export content".write(to: sourceURL, atomically: true, encoding: .utf8)

        let destURL = tempDir.appendingPathComponent("exported.yaml")

        try service.exportFile(from: sourceURL, to: destURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path))
        let content = try String(contentsOf: destURL, encoding: .utf8)
        XCTAssertEqual(content, "export content")
    }

    // MARK: - Import Tests

    func testImportFile() throws {
        let sourceURL = tempDir.appendingPathComponent("import_source.yaml")
        try "import content".write(to: sourceURL, atomically: true, encoding: .utf8)

        let destDir = tempDir.appendingPathComponent("import_dest")
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let resultURL = try service.importFile(from: sourceURL, to: destDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
        XCTAssertEqual(resultURL.lastPathComponent, "import_source.yaml")
    }

    func testImportFileRejectsSymbolicLinkSource() throws {
        let target = tempDir.appendingPathComponent("outside.txt")
        let link = tempDir.appendingPathComponent("squirrel.custom.yaml")
        try "do-not-touch".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let destDir = tempDir.appendingPathComponent("import_link_dest")
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        XCTAssertThrowsError(try service.importFile(from: link, to: destDir))
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "do-not-touch")
    }

    func testWriteFileContentRejectsSymbolicLinkDestination() throws {
        let target = tempDir.appendingPathComponent("outside.txt")
        let link = tempDir.appendingPathComponent("default.yaml")
        try "safe".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertThrowsError(
            try service.writeFileContent("unsafe", to: link, shouldBackup: false)
        )
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "safe")
    }

    // MARK: - ZIP Import Tests

    /// 用 ditto 打包目录，keepParent 控制 zip 内是否带顶层目录
    private func makeZip(contentsDir: URL, zipURL: URL, keepParent: Bool) throws {
        let process = Process()
        process.launchPath = "/usr/bin/ditto"
        process.arguments = keepParent
            ? ["-c", "-k", "--keepParent", contentsDir.path, zipURL.path]
            : ["-c", "-k", contentsDir.path, zipURL.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testImportZipWithParentDirectory() throws {
        let payloadDir = tempDir.appendingPathComponent("payload")
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)
        try "schema".write(to: payloadDir.appendingPathComponent("my.schema.yaml"), atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("with_parent.zip")
        try makeZip(contentsDir: payloadDir, zipURL: zipURL, keepParent: true)

        let rimeDir = tempDir.appendingPathComponent("rime")
        try FileManager.default.createDirectory(at: rimeDir, withIntermediateDirectories: true)

        try service.importZip(from: zipURL, to: rimeDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: rimeDir.appendingPathComponent("my.schema.yaml").path))
    }

    func testImportZipWithFlatFiles() throws {
        // 平铺 zip（无顶层目录）也应正确导入，而不是静默什么都不做
        let payloadDir = tempDir.appendingPathComponent("payload")
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)
        try "schema".write(to: payloadDir.appendingPathComponent("flat.schema.yaml"), atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("flat.zip")
        try makeZip(contentsDir: payloadDir, zipURL: zipURL, keepParent: false)

        let rimeDir = tempDir.appendingPathComponent("rime_flat")
        try FileManager.default.createDirectory(at: rimeDir, withIntermediateDirectories: true)

        try service.importZip(from: zipURL, to: rimeDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: rimeDir.appendingPathComponent("flat.schema.yaml").path))
    }

    func testImportZipRejectsSymbolicLinkEntry() throws {
        let outside = tempDir.appendingPathComponent("outside.yaml")
        try "safe".write(to: outside, atomically: true, encoding: .utf8)

        let payloadDir = tempDir.appendingPathComponent("symlink_payload")
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)
        try "schema".write(to: payloadDir.appendingPathComponent("safe.schema.yaml"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: payloadDir.appendingPathComponent("squirrel.custom.yaml"),
            withDestinationURL: outside
        )

        let zipURL = tempDir.appendingPathComponent("symlink.zip")
        try makeZip(contentsDir: payloadDir, zipURL: zipURL, keepParent: true)

        let rimeDir = tempDir.appendingPathComponent("rime_symlink")
        try FileManager.default.createDirectory(at: rimeDir, withIntermediateDirectories: true)

        XCTAssertThrowsError(try service.importZip(from: zipURL, to: rimeDir))
        XCTAssertFalse(FileManager.default.fileExists(atPath: rimeDir.appendingPathComponent("squirrel.custom.yaml").path))
        XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), "safe")
    }

    func testExportConfigExcludesPrivateAndBackupDirectories() throws {
        try "config".write(to: tempDir.appendingPathComponent("default.yaml"), atomically: true, encoding: .utf8)
        for name in ["backups", "build", "sync", "userdb", "backup_20260101_000000"] {
            let dir = tempDir.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try "private".write(to: dir.appendingPathComponent("data.txt"), atomically: true, encoding: .utf8)
        }

        let zipURL = tempDir.appendingPathComponent("export.zip")
        try service.exportConfigAsZip(from: tempDir, to: zipURL)

        let extractDir = tempDir.appendingPathComponent("extract")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        let process = Process()
        process.launchPath = "/usr/bin/ditto"
        process.arguments = ["-x", "-k", zipURL.path, extractDir.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let roots = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
        let exportedRoot = try XCTUnwrap(roots.first)
        for name in ["backups", "build", "sync", "userdb", "backup_20260101_000000"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: exportedRoot.appendingPathComponent(name).path))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedRoot.appendingPathComponent("default.yaml").path))
    }
}
