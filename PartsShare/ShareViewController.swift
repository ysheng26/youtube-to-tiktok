import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareModel(context: extensionContext)
        let host = UIHostingController(rootView: ShareScreen(model: model))
        host.view.backgroundColor = .systemBackground
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
}

@MainActor
final class ShareModel: ObservableObject {
    @Published var videoID: String?
    @Published var loading = true
    @Published var saved = false
    @Published var error: String?
    private let context: NSExtensionContext?
    init(context: NSExtensionContext?) { self.context = context }
    func load() async {
        defer { loading = false }
        for item in context?.inputItems as? [NSExtensionItem] ?? [] {
            for provider in item.attachments ?? [] {
                for type in [UTType.url.identifier, UTType.plainText.identifier] where provider.hasItemConformingToTypeIdentifier(type) {
                    guard let text = await read(provider, type: type) else { continue }
                    if let id = VideoLink.sharedID(from: text) { videoID = id; return }
                }
            }
            if let text = item.attributedContentText?.string, let id = VideoLink.sharedID(from: text) {
                videoID = id; return
            }
        }
        error = "Share a YouTube video link from YouTube or Safari to save it here."
    }
    private func read(_ provider: NSItemProvider, type: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { value, _ in
                let text: String?
                if let url = value as? URL { text = url.absoluteString }
                else if let string = value as? String { text = string }
                else if let data = value as? Data { text = String(data: data, encoding: .utf8) }
                else { text = nil }
                continuation.resume(returning: text)
            }
        }
    }
    func save() {
        guard !saved, let videoID else { return }
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ShareInbox.appGroup) else {
            error = "Parts couldn’t access its shared library. You can still copy the link and paste it into Parts."
            return
        }
        do {
            try ShareInbox(directory: container.appendingPathComponent("ShareInbox", isDirectory: true)).enqueue(videoID: videoID)
            error = nil
            saved = true
        } catch { self.error = "Couldn’t save this video. Please try again." }
    }
    func close() { context?.completeRequest(returningItems: nil) }
}

private struct ShareScreen: View {
    @ObservedObject var model: ShareModel
    private let accent = Color(red: 0.73, green: 0.98, blue: 0.36)
    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: model.saved ? "checkmark.circle.fill" : "rectangle.stack.fill")
                    .font(.system(size: 52)).foregroundStyle(accent)
                Text(model.saved ? "Saved to Parts" : "Save to Parts").font(.largeTitle.bold())
                if model.loading {
                    ProgressView("Reading video link…")
                } else if model.saved {
                    Text("Saved for later. Open Parts whenever you’re ready to watch.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                } else if let id = model.videoID {
                    Text("youtube.com/watch?v=\(id)").font(.subheadline.monospaced()).foregroundStyle(.secondary)
                    Text("Add this video to your library to watch later.").font(.subheadline).foregroundStyle(.secondary)
                }
                if let error = model.error { Text(error).foregroundStyle(.orange).multilineTextAlignment(.center) }
                Spacer()
                if model.saved || (!model.loading && model.videoID == nil) {
                    Button("Done") { model.close() }.buttonStyle(.borderedProminent)
                } else if !model.loading {
                    Button { model.save() } label: {
                        Text("Save video").font(.headline).frame(maxWidth: .infinity).padding(12)
                    }.buttonStyle(.borderedProminent)
                }
            }.padding(28).frame(maxWidth: .infinity)
                .navigationTitle("Parts").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.close() } } }
        }.tint(accent).preferredColorScheme(.dark).task { await model.load() }
    }
}
