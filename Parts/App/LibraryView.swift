import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: Library
    @State private var link = ""
    @State private var validation: String?
    @State private var selected: SavedVideo?
    @FocusState private var editing: Bool
    private let accent = Color(red: 0.73, green: 0.98, blue: 0.36)
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    HStack {
                        Label("parts", systemImage: "rectangle.stack.fill").font(.system(size: 28, weight: .black, design: .rounded))
                        Spacer()
                        Text("ONE VIDEO. LITTLE BY LITTLE.").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Long video.\nShort attention span.").font(.system(size: 43, weight: .bold, design: .rounded)).tracking(-2)
                        Text("Your next rabbit hole, one minute at a time.").foregroundStyle(.secondary)
                    }.padding(.top, 20)
                    VStack(alignment: .leading, spacing: 16) {
                        Label("START SOMETHING", systemImage: "sparkles").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                        HStack {
                            Image(systemName: "link").foregroundStyle(.secondary)
                            TextField("Paste a YouTube link", text: $link)
                                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .focused($editing).submitLabel(.go).onSubmit(openLink)
                            PasteButton(payloadType: String.self) { strings in
                                if let first = strings.first { link = first; validation = nil }
                            }.labelStyle(.iconOnly).tint(accent)
                        }.padding(14).background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                        if let validation { Text(validation).font(.footnote).foregroundStyle(.orange) }
                        Button(action: openLink) {
                            HStack { Spacer(); Text("Watch in parts"); Image(systemName: "arrow.up.right"); Spacer() }
                                .font(.headline).padding(17).background(accent, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black)
                        }.buttonStyle(.plain)
                        Text("60-second parts · Swipe to continue · Pick up anytime")
                            .font(.caption2).foregroundStyle(.secondary)
                    }.padding(20).background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24))
                    if library.videos.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("A LITTLE TEST DRIVE").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                            Button {
                                selected = library.open("aqz-KE-bpKQ")
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(accent)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Try Big Buck Bunny").font(.headline).foregroundStyle(.white)
                                        Text("An animated short from Blender").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                                }.padding(18).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain)
                        }
                    } else {
                        HStack { Text("YOUR RABBIT HOLES").font(.system(size: 11, weight: .bold, design: .monospaced)); Spacer(); Text("\(library.videos.count)").font(.caption) }.foregroundStyle(.secondary)
                        ForEach(library.videos.sorted { $0.updatedAt > $1.updatedAt }) { video in
                            Button { selected = video } label: { videoRow(video) }.buttonStyle(.plain)
                                .contextMenu { Button("Remove from library", role: .destructive) { library.remove(video) } }
                        }
                    }
                    Text("Made for the joy of getting sidetracked.")
                        .font(.caption).foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.vertical, 16)
                }.padding(24)
            }.background(Color(red: 0.045, green: 0.055, blue: 0.05)).toolbar(.hidden, for: .navigationBar)
                .fullScreenCover(item: $selected, onDismiss: openSharedVideo) { video in WatchView(video: video).environmentObject(library) }
                .onChange(of: library.sharedVideoIDToOpen, initial: true) { _, id in
                    guard id != nil else { return }
                    // Dismiss an existing player before presenting the shared video.
                    // This preserves progress and creates a fresh YouTube player.
                    if selected != nil { selected = nil }
                    else { openSharedVideo() }
                }
        }
    }
    private func openSharedVideo() {
        guard let id = library.sharedVideoIDToOpen else { return }
        library.sharedVideoIDToOpen = nil
        selected = library.open(id)
    }
    private func openLink() {
        guard let id = VideoLink.sharedID(from: link) else { validation = "Use a YouTube video link, like youtube.com/watch?v=… or youtu.be/…"; return }
        validation = nil; editing = false; selected = library.open(id); link = ""
    }
    private func videoRow(_ video: SavedVideo) -> some View {
        HStack(spacing: 15) {
            AsyncImage(url: URL(string: "https://i.ytimg.com/vi/\(video.id)/mqdefault.jpg")) { image in image.resizable().scaledToFill() } placeholder: { Color.white.opacity(0.1).overlay(Image(systemName: "play.fill")) }
                .frame(width: 100, height: 72).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 7) {
                Text(video.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(video.duration > 0 ? "Part \(video.timeline.index(at: video.position) + 1) of \(video.timeline.count) · Resume" : "Ready when you are")
                    .font(.caption).foregroundStyle(accent)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.fill").font(.caption).foregroundStyle(accent)
        }
    }
}
