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
}
