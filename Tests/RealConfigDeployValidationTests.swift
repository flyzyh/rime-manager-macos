import XCTest
@testable import RimeManager

/// Optional end-to-end validation:
/// RIME_VALIDATION_SOURCE=~/Library/Rime swift test --filter RealConfigDeployValidationTests
@MainActor
final class RealConfigDeployValidationTests: XCTestCase {
    func testApplyAndDeployRealConfigurationWhenEnabled() throws {
        let source = ProcessInfo.processInfo.environment["RIME_VALIDATION_SOURCE"]
        guard let source, !source.isEmpty else {
            throw XCTSkip("Set RIME_VALIDATION_SOURCE to run optional real-configuration validation.")
        }
        let sourceURL = URL(fileURLWithPath: (source as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("RIME_VALIDATION_SOURCE does not exist.")
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RimeRealValidation_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasSuffix(".yaml") {
                try fm.copyItem(at: file, to: tempDir.appendingPathComponent(file.lastPathComponent))
            }
        }
        if fm.fileExists(atPath: sourceURL.appendingPathComponent("dicts").path) {
            try fm.copyItem(
                at: sourceURL.appendingPathComponent("dicts"),
                to: tempDir.appendingPathComponent("dicts")
            )
        }

        let manager = ConfigManager()
        manager.loadAllConfigs(in: tempDir)
        XCTAssertNil(manager.loadError)
        try manager.applyAllConfigChanges(in: tempDir)

        let patchYAML = try String(contentsOf: tempDir.appendingPathComponent("rime_mint.custom.yaml"), encoding: .utf8)
        XCTAssertFalse(patchYAML.contains("\n  punctuator:\n"), "标点 patch 不能保留会覆盖 import_preset 的整体节点")
        XCTAssertTrue(patchYAML.contains("punctuator/half_shape"))

        let deployer = "/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer"
        guard fm.fileExists(atPath: deployer) else {
            throw XCTSkip("Squirrel deployer is not installed.")
        }
        let output = try XCTUnwrap(URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rime_deploy_\(UUID().uuidString).log"))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: deployer)
        process.arguments = ["--build", tempDir.path, "/Library/Input Methods/Squirrel.app/Contents/SharedSupport"]
        FileManager.default.createFile(atPath: output.path, contents: nil)
        process.standardOutput = try FileHandle(forWritingTo: output)
        process.standardError = process.standardOutput
        try process.run()
        process.waitUntilExit()
        let deployLog = try String(contentsOf: output, encoding: .utf8)
        XCTAssertEqual(process.terminationStatus, 0, deployLog)
    }
}
