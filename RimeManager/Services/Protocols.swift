import Foundation

// MARK: - File Managing

/// Protocol abstracting file system operations for testability.
protocol FileManaging {
    func scanDirectory(_ url: URL) -> [RimeConfigFile]
    func readFileContent(at url: URL) -> String
    func writeFileContent(_ content: String, to url: URL, shouldBackup: Bool) throws
    func fileExists(at url: URL) -> Bool
    func createFullBackup(of directoryURL: URL) -> URL?
    func exportConfigAsZip(from sourceURL: URL) -> URL?
    func exportFile(from sourceURL: URL, to destinationURL: URL) throws
    func importFile(from sourceURL: URL, to rimeDirURL: URL) throws -> URL
    func importZip(from zipURL: URL, to rimeDirURL: URL) throws
}

extension FileManagerService: FileManaging {}

// MARK: - Path Detecting

/// Protocol abstracting Rime path detection for testability.
protocol PathDetecting {
    var defaultRimeDirectory: URL { get }
    func isValidRimeDirectory(_ url: URL) -> Bool
    func detectDefaultRimeDirectory() -> URL?
    func findSchemaFiles(in directory: URL) -> [URL]
}

extension RimePathService: PathDetecting {}

// MARK: - Deploying

/// Protocol abstracting deployment operations for testability.
protocol Deploying {
    var isRimeConfigured: Bool { get }
}

extension DeployService: Deploying {}
