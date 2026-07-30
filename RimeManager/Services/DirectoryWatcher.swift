import Foundation

/// Watches a directory for file changes using FSEvents with proper debouncing.
final class DirectoryWatcher {
    private let url: URL
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.rimemanager.directorywatcher", qos: .utility)
    private var debounceWorkItem: DispatchWorkItem?
    private var retainedSelf: Unmanaged<DirectoryWatcher>?

    var onChange: (() -> Void)?

    init(url: URL) {
        self.url = url
    }

    func start() {
        guard stream == nil else { return }

        let paths = [url.path] as CFArray

        // Use passRetained to prevent wild pointer if watcher is released while stream is active
        let retained = Unmanaged.passRetained(self)
        self.retainedSelf = retained

        let callback: FSEventStreamCallback = { (
            _ streamRef: ConstFSEventStreamRef,
            clientCallBackInfo: UnsafeMutableRawPointer?,
            _ numEvents: Int,
            _ eventPaths: UnsafeMutableRawPointer,
            _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
            _ eventIds: UnsafePointer<FSEventStreamEventId>
        ) in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.scheduleDebouncedCallback()
        }

        var context = FSEventStreamContext(
            version: 0,
            info: retained.toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // latency in seconds
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents |
                                     kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }

        // Release the retained self
        retainedSelf?.release()
        retainedSelf = nil
    }

    /// Debounce rapid file system events using DispatchWorkItem cancellation.
    private func scheduleDebouncedCallback() {
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounceWorkItem = workItem

        queue.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    deinit {
        // Safety: ensure stream is stopped if deinit is called without explicit stop()
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        retainedSelf?.release()
    }
}
