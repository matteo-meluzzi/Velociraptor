import Foundation
import Testing
@testable import Velociraptor

struct FileTrackStoreTests {
    private let track = makeTrack([[(45, 7), (45.001, 7.001)], [(45.002, 7.002)]], name: "Ride")

    @Test func savedTrackLoadsBack() throws {
        let store = FileTrackStore(directory: makeTempDirectory())
        try store.save(track)
        #expect(store.load() == track)
    }

    @Test func loadWithoutFileIsNil() {
        #expect(FileTrackStore(directory: makeTempDirectory()).load() == nil)
    }

    @Test func clearRemovesTrack() throws {
        let store = FileTrackStore(directory: makeTempDirectory())
        try store.save(track)
        store.clear()
        #expect(store.load() == nil)
    }

    @Test func unreadableFileLoadsNilAndIsRemoved() throws {
        let directory = makeTempDirectory()
        let file = directory.appendingPathComponent("CurrentTrack.json")
        try Data("not json".utf8).write(to: file)
        #expect(FileTrackStore(directory: directory).load() == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func saveCreatesMissingDirectory() throws {
        let store = FileTrackStore(directory: makeTempDirectory().appendingPathComponent("a/b", isDirectory: true))
        try store.save(track)
        #expect(store.load() == track)
    }

    @Test func secondSaveReplacesFirst() throws {
        let store = FileTrackStore(directory: makeTempDirectory())
        try store.save(track)
        let other = makeTrack([[(10, 10)]], name: "Other")
        try store.save(other)
        #expect(store.load() == other)
    }
}
