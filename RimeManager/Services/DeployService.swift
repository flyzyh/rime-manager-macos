import Foundation

/// Checks if Rime configuration exists on the system.
final class DeployService {
    private let fm = FileManager.default

    var rimeDir: URL {
        fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Rime")
    }

    /// Check if Rime is already set up (has default.yaml)
    var isRimeConfigured: Bool {
        fm.fileExists(atPath: rimeDir.appendingPathComponent("default.yaml").path)
    }
}
