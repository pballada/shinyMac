import Foundation
import Testing
@testable import ShinyCore

@Suite struct DiskTreeTests {
    @Test func buildsSizedTreeAndFoldsSmallItems() throws {
        let root = try TempFolder()
        try root.file("Movies/a.mov", bytes: 400_000)
        try root.file("Movies/b.mov", bytes: 200_000)
        try root.file("Docs/note1.txt", bytes: 100)
        try root.file("Docs/note2.txt", bytes: 100)
        try root.file("big.bin", bytes: 300_000)

        let tree = DiskTree.build(root: root.url, foldBelow: 50_000, progress: ScanProgress())

        #expect(tree.size >= 900_000)
        #expect(tree.children.first?.name == "Movies", "Largest first")
        let movies = try #require(tree.children.first)
        #expect(movies.children.map(\.name) == ["a.mov", "b.mov"])
        #expect(movies.parent === tree)
        // The tiny Docs folder is folded into an aggregate at the root.
        let aggregate = try #require(tree.children.last)
        #expect(aggregate.isAggregate)
        #expect(aggregate.name == "1 smaller item")
    }

    @Test func removingAChildShrinksAncestors() throws {
        let root = try TempFolder()
        try root.file("Movies/a.mov", bytes: 400_000)
        try root.file("Movies/b.mov", bytes: 200_000)

        let tree = DiskTree.build(root: root.url, foldBelow: 1, progress: ScanProgress())
        let movies = try #require(tree.children.first)
        let a = try #require(movies.children.first)
        let before = tree.size

        movies.remove(a)

        #expect(movies.children.map(\.name) == ["b.mov"])
        #expect(tree.size == before - a.size)
        #expect(a.ancestry.count == 3)
    }
}
