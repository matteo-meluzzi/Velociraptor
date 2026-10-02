import Foundation

protocol TrackStoring: Sendable {
    /// `nil` when nothing is stored or the stored track cannot be read (the unreadable file is removed).
    func load() -> Track?
    func save(_ track: Track) throws
    /// Removes the track and its progress.
    func clear()
    /// `nil` when nothing is stored or the stored progress cannot be read (the unreadable file is removed).
    func loadProgress() -> ProgressState?
    func saveProgress(_ progress: ProgressState) throws
    func clearProgress()
}

/// Keeps the current track and the progress along it as JSON so they survive relaunches and crashes.
struct FileTrackStore: TrackStoring {
    let directory: URL

    private var fileURL: URL { directory.appendingPathComponent("CurrentTrack.json") }
    private var progressURL: URL { directory.appendingPathComponent("CurrentTrackProgress.json") }

    static var applicationSupport: FileTrackStore {
        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return FileTrackStore(directory: directory)
    }

    func load() -> Track? {
        read(Track.self, from: fileURL)
    }

    func save(_ track: Track) throws {
        try write(track, to: fileURL)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        clearProgress()
    }

    func loadProgress() -> ProgressState? {
        read(ProgressState.self, from: progressURL)
    }

    func saveProgress(_ progress: ProgressState) throws {
        try write(progress, to: progressURL)
    }

    func clearProgress() {
        try? FileManager.default.removeItem(at: progressURL)
    }

    private func read<Value: Decodable>(_ type: Value.Type, from url: URL) -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(type, from: data) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return value
    }

    private func write<Value: Encodable>(_ value: Value, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
