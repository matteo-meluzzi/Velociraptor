import Foundation

protocol TrackStoring {
    /// `nil` when nothing is stored or the stored track cannot be read (the unreadable file is removed).
    func load() -> Track?
    func save(_ track: Track) throws
    func clear()
}

/// Keeps the current track as JSON so it survives relaunches and crashes.
struct FileTrackStore: TrackStoring {
    let directory: URL

    private var fileURL: URL { directory.appendingPathComponent("CurrentTrack.json") }

    static var applicationSupport: FileTrackStore {
        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return FileTrackStore(directory: directory)
    }

    func load() -> Track? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL),
              let track = try? JSONDecoder().decode(Track.self, from: data) else {
            clear()
            return nil
        }
        return track
    }

    func save(_ track: Track) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(track).write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
