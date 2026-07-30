import Foundation

/// Represents a single file in the Rime configuration directory.
struct RimeConfigFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let fileType: FileType
    let isDirectory: Bool
    let children: [RimeConfigFile]?

    var path: String {
        url.path
    }

    var relativePath: String {
        // Strip the Rime root from the path for display
        url.path
    }

    var fileSize: Int64? {
        guard !isDirectory else { return nil }
        return (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize as? Int64
    }

    var modificationDate: Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    init(url: URL, isDirectory: Bool = false, children: [RimeConfigFile]? = nil) {
        self.url = url
        self.name = url.lastPathComponent
        self.fileType = FileType.detect(from: url.lastPathComponent, isDirectory: isDirectory)
        self.isDirectory = isDirectory
        self.children = children
    }

    /// A leaf file (no children).
    init(url: URL) {
        self.init(url: url, isDirectory: false, children: nil)
    }
}
