import Foundation

extension VideoLink {
    /// Share payloads can contain a title and other text around the URL.
    static func sharedID(from text: String) -> String? {
        if let id = id(from: text) { return id }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in detector.matches(in: text, range: range) {
            if let url = match.url, let id = id(from: url.absoluteString) { return id }
        }
        return nil
    }
}

/// Separate files keep simultaneous shares from overwriting one another or app progress.
struct ShareInbox {
    static let appGroup = "group.com.shengy.parts"
    let directory: URL
    struct Entry: Codable {
        let videoID: String
        let savedAt: Date
    }
    func enqueue(videoID: String) throws {
        guard VideoLink.id(from: "https://youtu.be/\(videoID)") == videoID else { throw InboxError.invalidVideo }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let entry = Entry(videoID: videoID, savedAt: Date())
        try JSONEncoder().encode(entry).write(to: directory.appendingPathComponent(UUID().uuidString + ".json"), options: .atomic)
    }
    func pending() throws -> [(url: URL, entry: Entry)] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url), let entry = try? JSONDecoder().decode(Entry.self, from: data),
                      VideoLink.id(from: "https://youtu.be/\(entry.videoID)") == entry.videoID else { return nil }
                return (url: url, entry: entry)
            }.sorted { $0.entry.savedAt < $1.entry.savedAt }
    }
    func acknowledge(_ url: URL) throws { try FileManager.default.removeItem(at: url) }
    enum InboxError: Error { case invalidVideo }
}

/// Public entry point used by the Watch in Parts Share Sheet shortcut.
enum PartsLink {
    static func videoID(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "parts", url.host?.lowercased() == "watch",
              url.user == nil, url.password == nil, url.port == nil,
              url.path.isEmpty || url.path == "/",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let values = items.filter { $0.name == "url" }
        guard values.count == 1, let text = values.first?.value else { return nil }
        return VideoLink.sharedID(from: text)
    }
}
