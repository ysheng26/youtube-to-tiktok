import Foundation

struct VideoLink {
    static func id(from input: String) -> String? {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: input.contains("://") ? input : "https://" + input),
              let host = url.host?.lowercased(), ["https", "http"].contains(url.scheme ?? "") else { return nil }
        let segments = url.pathComponents.filter { $0 != "/" }
        let candidate: String?
        switch host {
        case "youtu.be", "www.youtu.be": candidate = segments.first
        case "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com":
            if segments.first == "watch" {
                candidate = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "v" }?.value
            } else if ["shorts", "embed", "live"].contains(segments.first ?? "") && segments.count > 1 {
                candidate = segments[1]
            } else { candidate = nil }
        default: candidate = nil
        }
        guard let candidate, candidate.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else { return nil }
        return candidate
    }
}

struct PartTimeline {
    let duration: Double
    let length: Double
    init(duration: Double, length: Double = 60) {
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.length = length.isFinite && length > 0 ? length : 60
    }
    var count: Int { duration > 0 ? Int(ceil(duration / length)) : 0 }
    func index(at time: Double) -> Int {
        guard count > 0, time.isFinite else { return 0 }
        return min(count - 1, max(0, Int(floor(max(0, time) / length))))
    }
    func start(_ index: Int) -> Double { Double(min(max(0, index), max(0, count - 1))) * length }
    func end(_ index: Int) -> Double { min(duration, start(index) + length) }
}

struct SavedVideo: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var author: String = "YouTube"
    var duration: Double = 0
    var position: Double = 0
    var updatedAt: Date = Date()
    var url: URL { URL(string: "https://www.youtube.com/watch?v=\(id)")! }
    var timeline: PartTimeline { PartTimeline(duration: duration) }
}
