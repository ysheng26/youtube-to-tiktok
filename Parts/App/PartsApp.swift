import SwiftUI

@main
struct PartsApp: App {
    @StateObject private var library = Library()
    var body: some Scene {
        WindowGroup {
            LibraryView().environmentObject(library).preferredColorScheme(.dark)
                .tint(.mint)
        }
    }
}

@MainActor
final class Library: ObservableObject {
    @Published var videos: [SavedVideo] = []
    private let key = "parts.library.v1"
    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([SavedVideo].self, from: data) { videos = saved }
    }
    func save(_ video: SavedVideo) {
        if let index = videos.firstIndex(where: { $0.id == video.id }) { videos[index] = video }
        else { videos.insert(video, at: 0) }
        persist()
    }
    func remove(_ video: SavedVideo) { videos.removeAll { $0.id == video.id }; persist() }
    private func persist() {
        if let data = try? JSONEncoder().encode(videos) { UserDefaults.standard.set(data, forKey: key) }
    }
    func open(_ id: String) -> SavedVideo {
        if let existing = videos.first(where: { $0.id == id }) { return existing }
        let video = SavedVideo(id: id, title: "Your next rabbit hole")
        save(video)
        return video
    }
}

extension Double {
    var timestamp: String {
        guard isFinite else { return "0:00" }
        let value = max(0, Int(self))
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) : String(format: "%d:%02d", value / 60, value % 60)
    }
}
