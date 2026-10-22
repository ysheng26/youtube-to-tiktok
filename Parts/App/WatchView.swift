import SwiftUI

struct WatchView: View {
    @EnvironmentObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var video: SavedVideo
    @StateObject private var playback = Playback()
    @State private var showParts = false
    @State private var slow = false
    @State private var scrubPosition: Double?
    @State private var lastSaved = Date.distantPast
    @GestureState private var dragOffset: CGFloat = 0
    @State private var pageOffset: CGFloat = 0
    @State private var pageOpacity: Double = 1
    @State private var isTransitioning = false
    @State private var transitionTask: Task<Void, Never>?
    @State private var pageHeight: CGFloat = 600
    private let accent = Color(red: 0.73, green: 0.98, blue: 0.36)
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                GeometryReader { page in
                    VStack(spacing: 0) {
                        Spacer(minLength: 8)
                        YouTubePlayer(video: video, playback: playback)
                            .frame(height: max(200, min(geometry.size.width * 9 / 16, geometry.size.height * 0.48)))
                            .accessibilityLabel("YouTube video player")
                        Spacer(minLength: 8)
                        ViewThatFits(in: .vertical) {
                            paddedControls
                            ScrollView { paddedControls }
                                .scrollBounceBehavior(.basedOnSize)
                        }
                        .frame(height: min(280, geometry.size.height * 0.44), alignment: .bottom)
                    }
                    .frame(width: page.size.width, height: page.size.height)
                    .offset(y: reduceMotion ? 0 : pageOffset + dragOffset)
                    .opacity(pageOpacity)
                    .allowsHitTesting(!isTransitioning)
                    .frame(width: page.size.width, height: page.size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .simultaneousGesture(partSwipe)
                    .onAppear { pageHeight = page.size.height }
                    .onChange(of: page.size.height) { _, height in pageHeight = height }
                }
            }
            .background(Color.black.ignoresSafeArea())
        }
            .sheet(isPresented: $showParts) {
                NavigationStack {
                    List(0..<playback.timeline.count, id: \.self) { index in
                        Button { showParts = false; switchPart(to: index) } label: {
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
            .onChange(of: playback.part) { _, _ in scrubPosition = nil; save() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { cancelTransition(); playback.pause(); save() } }
            .onDisappear { cancelTransition(); playback.pause(); save() }
    }
    private var paddedControls: some View {
        watchControls.padding(.horizontal, 20).padding(.vertical, 12)
    }
    private var partSwipe: some Gesture {
        DragGesture(minimumDistance: 15)
            .updating($dragOffset) { value, offset, _ in
                guard !isTransitioning, scrubPosition == nil,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                let target = playback.part + (value.translation.height < 0 ? 1 : -1)
                let canMove = (0..<playback.timeline.count).contains(target)
                offset = value.translation.height * (canMove ? 1 : 0.18)
            }
            .onEnded { value in
                guard !isTransitioning, scrubPosition == nil,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                let direction = value.translation.height < 0 ? 1 : -1
                let target = playback.part + direction
                let canMove = (0..<playback.timeline.count).contains(target)
                let distance = value.translation.height * (canMove ? 1 : 0.18)
                if canMove && (abs(value.translation.height) > 60 || abs(value.predictedEndTranslation.height) > 150) {
                    switchPart(to: target, startingOffset: distance)
                } else {
                    pageOffset = distance
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { pageOffset = 0 }
                }
            }
    }
    private func switchPart(to index: Int, startingOffset: CGFloat = 0) {
        guard !isTransitioning, index != playback.part,
              (0..<playback.timeline.count).contains(index) else { return }
        let direction: CGFloat = index > playback.part ? -1 : 1
        isTransitioning = true
        pageOffset = startingOffset
        UISelectionFeedbackGenerator().selectionChanged()
        transitionTask = Task { @MainActor in
            withAnimation(.easeIn(duration: 0.16)) {
                if reduceMotion { pageOpacity = 0 } else { pageOffset = direction * pageHeight }
            }
            do { try await Task.sleep(for: .milliseconds(170)) } catch { return }
            guard !Task.isCancelled else { return }
            playback.go(to: index)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { pageOffset = -direction * pageHeight }
            // Give SwiftUI a frame to place the incoming page on the opposite side.
            do { try await Task.sleep(for: .milliseconds(35)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                pageOffset = 0
                pageOpacity = 1
            }
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            isTransitioning = false
            transitionTask = nil
        }
    }
    private func cancelTransition() {
        transitionTask?.cancel()
        transitionTask = nil
        isTransitioning = false
        pageOffset = 0
        pageOpacity = 1
    }
    private var header: some View {
        HStack {
            Button { save(); dismiss() } label: {
                Image(systemName: "chevron.left").font(.title3).frame(width: 44, height: 44)
            }.accessibilityLabel("Back to library")
            Spacer()
            Text(playback.timeline.count > 0 ? "PART \(playback.part + 1) OF \(playback.timeline.count)" : "YOUR VIDEO, IN PARTS")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(accent)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(.black.opacity(0.35), in: Capsule())
            Spacer()
            ShareLink(item: video.url) {
                Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
            }.accessibilityLabel("Share original video")
        }.foregroundStyle(.white).padding(.horizontal, 12).padding(.top, 4)
    }
    private var watchControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title).font(.headline).lineLimit(2)
                Text(video.author).font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            if let error = playback.error {
                Label(error, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.orange)
            } else if playback.duration == 0 {
                VStack(alignment: .leading, spacing: 8) {
                    if !playback.ready { ProgressView().tint(accent) }
                    Text(playback.ready ? "Tap play to start your series." : "Getting your video ready…")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    if playback.ready {
                        Button("Play video", systemImage: "play.fill") { playback.toggle() }.buttonStyle(.borderedProminent)
                    }
                    if slow { Text("Still waiting? Check your connection, or try another video.").font(.caption).foregroundStyle(.secondary) }
                }
            } else {
                HStack(spacing: 12) {
                    Button { playback.toggle() } label: {
                        Image(systemName: playback.playing ? "pause.fill" : "play.fill").font(.title3).frame(width: 44, height: 44)
                    }.accessibilityLabel(playback.playing ? "Pause" : "Play")
                    Slider(value: Binding(
                        get: { scrubPosition ?? partPosition },
                        set: { scrubPosition = $0 }
                    ), in: 0...max(0.1, partDuration), onEditingChanged: { editing in
                        if !editing, let offset = scrubPosition {
                            playback.seek(to: offset)
                            scrubPosition = nil
                        }
                    }).tint(accent).accessibilityLabel("Position within this part")
                    Text("\((scrubPosition ?? partPosition).timestamp) / \(partDuration.timestamp)")
                        .font(.caption2.monospacedDigit()).fixedSize()
                }
                HStack(spacing: 12) {
                    Button { switchPart(to: playback.part - 1) } label: {
                        Text("Prev").font(.subheadline.bold())
                            .padding(.horizontal, 18).frame(minHeight: 44)
                            .background(.white.opacity(0.1), in: Capsule())
                    }.disabled(playback.part == 0).accessibilityLabel("Previous part")
                    Button { showParts = true } label: {
                        Label("All parts", systemImage: "square.grid.2x2").font(.subheadline).frame(minHeight: 44)
                    }
                    Spacer(minLength: 0)
                    Button { switchPart(to: playback.part + 1) } label: {
                        Text("Next")
                            .font(.subheadline.bold()).padding(.horizontal, 18).frame(minHeight: 44)
                            .background(accent, in: Capsule()).foregroundStyle(.black)
                    }.disabled(playback.part == playback.timeline.count - 1)
                        .accessibilityLabel("Next part")
                }.buttonStyle(.plain)
                Text(playback.part == playback.timeline.count - 1 ? "Final part · Loops until you leave" : "Loops automatically · Swipe up for next")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            Link("Open original on YouTube ↗", destination: video.url)
                .font(.caption).foregroundStyle(.white.opacity(0.65)).padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

    }
    private var partDuration: Double {
        playback.timeline.end(playback.part) - playback.timeline.start(playback.part)
    }
    private var partPosition: Double {
        min(max(0, playback.position - playback.timeline.start(playback.part)), max(0, partDuration))
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
