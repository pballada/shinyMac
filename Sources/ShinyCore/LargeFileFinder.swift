import Foundation
import Synchronization
import UniformTypeIdentifiers

/// Broad file categories used to filter large files.
public enum FileKind: String, CaseIterable, Sendable, Identifiable {
    case video = "Videos"
    case audio = "Audio"
    case picture = "Pictures"
    case archive = "Archives"
    case diskImage = "Disk Images"
    case document = "Documents"
    case application = "Apps & Bundles"
    case other = "Other"

    public var id: Self { self }

    public var symbol: String {
        switch self {
        case .video: "film.fill"
        case .audio: "music.note"
        case .picture: "photo.fill"
        case .archive: "archivebox.fill"
        case .diskImage: "opticaldiscdrive.fill"
        case .document: "doc.richtext.fill"
        case .application: "app.fill"
        case .other: "doc.fill"
        }
    }

    public static func of(_ url: URL, isPackage: Bool = false) -> FileKind {
        if isPackage { return url.pathExtension == "app" ? .application : .other }
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return .other }
        if type.conforms(to: .audiovisualContent) && !type.conforms(to: .audio) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .image) { return .picture }
        if type.conforms(to: .diskImage) || ["dmg", "iso", "img", "sparseimage", "sparsebundle"].contains(url.pathExtension.lowercased()) {
            return .diskImage
        }
        if type.conforms(to: .archive) { return .archive }
        if type.conforms(to: .pdf) || type.conforms(to: .presentation) || type.conforms(to: .spreadsheet)
            || type.conforms(to: .text) || type.conforms(to: .compositeContent) {
            return .document
        }
        return .other
    }
}

public struct LargeFile: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let size: Int64
    public let kind: FileKind
    public let lastOpened: Date?
    public let modified: Date?

    public init(url: URL, size: Int64, kind: FileKind, lastOpened: Date?, modified: Date?) {
        self.url = url
        self.size = size
        self.kind = kind
        self.lastOpened = lastOpened
        self.modified = modified
    }

    /// The most recent sign of use: last opened, or last modified if macOS never recorded an open.
    public var lastUsed: Date? { [lastOpened, modified].compactMap { $0 }.max() }
}

/// Walks the home folder for big files, in parallel. `~/Library` and hidden folders are skipped; packages such as
/// photo libraries and apps count as one item.
public enum LargeFileFinder {
    /// Dependency and build folders: huge numbers of tiny files, never the big files people want to review.
    static let skippedFolderNames: Set<String> = [
        "node_modules", "Pods", "venv", "site-packages", "__pycache__", "DerivedData", "bower_components", "vendor",
    ]

    public static func scan(root: URL = Paths.home, minimumSize: Int64, progress: ScanProgress) -> [LargeFile] {
        let skipped: Set<String> = [
            root.appending(path: "Library").path(percentEncoded: false),
            root.appending(path: "Applications").path(percentEncoded: false),
        ]
        let collected = Mutex<[LargeFile]>([])

        ParallelWalker.walk(root: root, progress: progress) { url, values in
            if values.isDirectory == true, values.isPackage != true {
                let skip = skipped.contains(url.path(percentEncoded: false).trimmingSuffix("/"))
                    || skippedFolderNames.contains(url.lastPathComponent)
                return !skip
            }
            if let file = evaluate(url, values: values, minimumSize: minimumSize, progress: progress) {
                collected.withLock { $0.append(file) }
            }
            return false
        }
        return collected.withLock { $0 }.sorted { $0.size > $1.size }
    }

    /// A large file (or package, measured as a whole), or nil if it's under the threshold.
    private static func evaluate(_ url: URL, values: URLResourceValues, minimumSize: Int64, progress: ScanProgress) -> LargeFile? {
        let isPackage = values.isDirectory == true && values.isPackage == true
        let size = isPackage ? FileSizer.size(of: url) : FileSizer.allocatedSize(values)
        guard size >= minimumSize else { return nil }
        progress.found(bytes: size)
        return LargeFile(
            url: url, size: size, kind: FileKind.of(url, isPackage: isPackage),
            lastOpened: values.contentAccessDate, modified: values.contentModificationDate
        )
    }

}

extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) && count > suffix.count ? String(dropLast(suffix.count)) : self
    }
}
