import Foundation

/// Unified error type for the application.
enum AppError: LocalizedError, Equatable {
    case fileReadFailed(URL)
    case fileWriteFailed(URL, String)
    case yamlParseFailed(String)
    case deployFailed(String)
    case importFailed(String)
    case backupFailed(String)
    case directoryNotSet
    case configLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let url):
            return "Failed to read file: \(url.lastPathComponent)"
        case .fileWriteFailed(let url, let reason):
            return "Failed to write \(url.lastPathComponent): \(reason)"
        case .yamlParseFailed(let detail):
            return "YAML parse error: \(detail)"
        case .deployFailed(let reason):
            return "Deployment failed: \(reason)"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        case .backupFailed(let reason):
            return "Backup failed: \(reason)"
        case .directoryNotSet:
            return "Rime directory not configured"
        case .configLoadFailed(let detail):
            return "Config load failed: \(detail)"
        }
    }

    /// Localized description using the i18n system.
    var localizedDescription: String {
        switch self {
        case .fileReadFailed(let url):
            return String(format: "error.file_read".localized, url.lastPathComponent)
        case .fileWriteFailed(let url, let reason):
            return String(format: "error.file_write".localized, url.lastPathComponent, reason)
        case .yamlParseFailed(let detail):
            return String(format: "error.yaml_parse".localized, detail)
        case .deployFailed(let reason):
            return String(format: "error.deploy".localized, reason)
        case .importFailed(let reason):
            return String(format: "error.import".localized, reason)
        case .backupFailed(let reason):
            return String(format: "error.backup".localized, reason)
        case .directoryNotSet:
            return "error.dir_not_set".localized
        case .configLoadFailed(let detail):
            return String(format: "error.config_load".localized, detail)
        }
    }
}
