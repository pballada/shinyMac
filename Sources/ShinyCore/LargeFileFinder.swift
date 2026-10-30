import Foundation
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

/// Walks the home folder for big files. `~/Library` and hidden folders are skipped; packages such as
/// photo libraries and apps count as one item.
public enum LargeFileFinder {
    static let keys: [URLResourceKey] = [
        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
        .contentAccessDateKey, .contentModificationDateKey,
    ]

    public static func scan(root: URL = Paths.home, minimumSize: Int64, progress: ScanProgress) -> [LargeFile] {
        let skipped: Set<String> = [
            root.appending(path: "Library").path(percentEncoded: false),
            root.appending(path: "Applications").path(percentEncoded: false),
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles], errorHandler: { _, _ in true }
        ) else { return [] }

        var results: [LargeFile] = []
        var visited = 0
        for case let url as URL in enumerator {
            visited += 1
            if visited.isMultiple(of: 256) {
                if Task.isCancelled { break }
                progress.update(detail: Paths.abbreviated(url.deletingLastPathComponent()))
            }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isSymbolicLink != true else { continue }

            let size: Int64
            let isPackage = values.isPackage == true
            if values.isDirectory == true {
                if skipped.contains(url.path(percentEncoded: false).trimmingSuffix("/")) {
                    enumerator.skipDescendants()
                    continue
                }
                guard isPackage else { continue }
                enumerator.skipDescendants()
                size = FileSizer.size(of: url)
            } else {
                size = FileSizer.allocatedSize(values)
            }

            guard size >= minimumSize else { continue }
            results.append(LargeFile(
                url: url, size: size, kind: FileKind.of(url, isPackage: isPackage),
                lastOpened: values.contentAccessDate, modified: values.contentModificationDate
            ))
            progress.found(bytes: size)
        }
        return results.sorted { $0.size > $1.size }
    }
}

extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) && count > suffix.count ? String(dropLast(suffix.count)) : self
    }
}
