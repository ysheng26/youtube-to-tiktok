import SwiftUI

@main
struct PartsApp: App {
    @StateObject private var library = Library()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            LibraryView().environmentObject(library).preferredColorScheme(.dark)
                .tint(.mint)
                .onOpenURL { library.receiveWatchLink($0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { library.importSharedVideos() }
                }
        }
    }
}

@MainActor
final class Library: ObservableObject {
    @Published var videos: [SavedVideo] = []
    @Published var watchRequest: WatchRequest?
    @Published var watchLinkError: String?
    private let key = "parts.library.v1"
    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([SavedVideo].self, from: data) { videos = saved }
        importSharedVideos()
    }
    func importSharedVideos() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ShareInbox.appGroup) else { return }
        let inbox = ShareInbox(directory: container.appendingPathComponent("ShareInbox", isDirectory: true))
        guard let pending = try? inbox.pending(), !pending.isEmpty else { return }
        var updated = videos
        for (_, entry) in pending {
            if let index = updated.firstIndex(where: { $0.id == entry.videoID }) {
                // Re-sharing a video preserves its title and playback progress.
                updated[index].updatedAt = max(updated[index].updatedAt, entry.savedAt)
            } else {
                updated.insert(SavedVideo(id: entry.videoID, title: "Shared from YouTube", updatedAt: entry.savedAt), at: 0)
            }
        }
        guard let data = try? JSONEncoder().encode(updated) else { return }
        UserDefaults.standard.set(data, forKey: key)
        videos = updated
        for (url, _) in pending { try? inbox.acknowledge(url) }
    }
    struct WatchRequest: Equatable, Identifiable {
        let id = UUID()
        let videoID: String
    }
    func receiveWatchLink(_ url: URL) {
        guard let id = PartsLink.videoID(from: url) else {
            watchLinkError = "This link doesn’t contain a supported YouTube video."
            return
        }
        watchLinkError = nil
        _ = open(id)
        watchRequest = WatchRequest(videoID: id)
    }
    func acknowledgeWatchRequest(_ request: WatchRequest) {
        if watchRequest == request { watchRequest = nil }
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
