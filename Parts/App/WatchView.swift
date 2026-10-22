import SwiftUI

struct WatchView: View {
    @EnvironmentObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State var video: SavedVideo
    @StateObject private var playback = Playback()
    @State private var showParts = false
    @State private var slow = false
    @State private var lastSaved = Date.distantPast
    private let accent = Color(red: 0.73, green: 0.98, blue: 0.36)
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { save(); dismiss() } label: { Image(systemName: "chevron.left").font(.title3).padding(12) }.accessibilityLabel("Back to library")
                Spacer()
                Text("parts").font(.system(.title3, design: .rounded, weight: .black))
                Spacer()
                ShareLink(item: video.url) { Image(systemName: "square.and.arrow.up").padding(12) }.accessibilityLabel("Share original video")
            }.foregroundStyle(.white).padding(.horizontal, 12)
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 10) {
                Text(playback.timeline.count > 0 ? "PART \(playback.part + 1) OF \(playback.timeline.count)" : "YOUR VIDEO, IN PARTS")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(accent)
                Text(video.title).font(.title2.bold()).lineLimit(2)
                Text(video.author).font(.subheadline).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            YouTubePlayer(video: video, playback: playback)
                .frame(height: max(210, min(300, UIScreen.main.bounds.width * 9 / 16)))
                .accessibilityLabel("YouTube video player")
            VStack(spacing: 22) {
                if let error = playback.error {
                    Label(error, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.orange)
                } else if playback.duration == 0 {
                    VStack(spacing: 8) {
                        if !playback.ready { ProgressView().tint(accent) }
                        Text(playback.ready ? "Tap play above to start your series." : "Getting your video ready…").font(.subheadline).foregroundStyle(.secondary)
                        if slow { Text("Still waiting? Check your connection, or try another video.").font(.caption).foregroundStyle(.secondary) }
                    }
                } else {
                    ProgressView(value: min(1, max(0, (playback.position - playback.timeline.start(playback.part)) / max(1, playback.timeline.end(playback.part) - playback.timeline.start(playback.part)))))
                        .tint(accent)
                    HStack {
                        Text("\(playback.timeline.start(playback.part).timestamp) – \(playback.timeline.end(playback.part).timestamp)")
                        Spacer()
                        Button { showParts = true } label: { Label("All parts", systemImage: "square.grid.2x2") }
                    }.font(.caption.monospaced()).foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        Button { playback.go(to: playback.part - 1) } label: { Image(systemName: "arrow.down").padding(18).background(.white.opacity(0.08), in: Circle()) }
                            .disabled(playback.part == 0).accessibilityLabel("Previous part")
                        Button { playback.go(to: playback.completed && playback.part == playback.timeline.count - 1 ? 0 : playback.part + 1) } label: {
                            HStack { Text(playback.completed && playback.part == playback.timeline.count - 1 ? "Watch again" : "Next part"); Image(systemName: "arrow.up") }
                                .font(.headline).frame(maxWidth: .infinity).padding(18).background(accent, in: Capsule()).foregroundStyle(.black)
                        }.disabled(!playback.completed && playback.part == playback.timeline.count - 1)
                    }.buttonStyle(.plain)
                    Text(playback.completed ? (playback.part == playback.timeline.count - 1 ? "That’s the whole rabbit hole. Nice." : "Part finished. Swipe up for the next one.") : "Swipe up here for the next part")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(24).frame(maxWidth: .infinity, minHeight: 200).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 35).onEnded { value in
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    if value.translation.height < -35 && playback.part < playback.timeline.count - 1 { playback.go(to: playback.part + 1) }
                    else if value.translation.height > 35 && playback.part > 0 { playback.go(to: playback.part - 1) }
                })
            Spacer(minLength: 0)
            Link("Open original on YouTube ↗", destination: video.url).font(.caption).foregroundStyle(.secondary).padding(.bottom, 18)
        }.background(Color(red: 0.035, green: 0.045, blue: 0.04))
            .sheet(isPresented: $showParts) {
                NavigationStack {
                    List(0..<playback.timeline.count, id: \.self) { index in
                        Button { playback.go(to: index); showParts = false } label: {
                            HStack {
                                Text("Part \(index + 1)").foregroundStyle(index == playback.part ? accent : .white)
                                Spacer()
                                Text("\(playback.timeline.start(index).timestamp) – \(playback.timeline.end(index).timestamp)").foregroundStyle(.secondary).font(.caption.monospaced())
                            }.padding(.vertical, 8)
                        }
                    }.navigationTitle("All parts").toolbar { Button("Done") { showParts = false } }
                }.presentationDetents([.medium, .large])
            }
            .task {
                await loadMetadata()
            }
            .task {
                try? await Task.sleep(for: .seconds(15))
                if !Task.isCancelled { slow = true }
            }
            .onChange(of: playback.position) { _, _ in
                if Date().timeIntervalSince(lastSaved) >= 5 { save() }
            }
            .onChange(of: playback.part) { _, _ in save() }
            .onChange(of: playback.completed) { _, _ in save() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { playback.pause(); save() } }
            .onDisappear { playback.pause(); save() }
    }
    private func save() {
        lastSaved = Date()
        video.duration = playback.duration > 0 ? playback.duration : video.duration
        if playback.duration > 0 { video.position = playback.position }
        video.updatedAt = Date()
        library.save(video)
    }
    private func loadMetadata() async {
        struct Metadata: Decodable { let title: String; let author_name: String }
        var components = URLComponents(string: "https://www.youtube.com/oembed")!
        components.queryItems = [URLQueryItem(name: "url", value: video.url.absoluteString), URLQueryItem(name: "format", value: "json")]
        guard let url = components.url else { return }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let metadata = try JSONDecoder().decode(Metadata.self, from: data)
            guard !Task.isCancelled else { return }
            video.title = metadata.title; video.author = metadata.author_name
            save()
        } catch { /* Playback remains available even when metadata is unavailable. */ }
    }
}
