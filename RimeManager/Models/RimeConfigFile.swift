import Foundation

/// Represents a single file in the Rime configuration directory.
/// 以文件路径作为身份：目录刷新后同一文件的新实例与旧实例可比较，
/// 选中状态不会因 watcher 触发的重扫描而丢失。
struct RimeConfigFile: Identifiable, Hashable {
    var id: URL { url }
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
