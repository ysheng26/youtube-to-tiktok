import XCTest
@testable import PartsCore

final class ShareInboxTests: XCTestCase {
    func testSharedTextExtractsAYouTubeLink() {
        XCTAssertEqual(VideoLink.sharedID(from: "Watch this 🎬 https://youtu.be/aqz-KE-bpKQ?si=hello"), "aqz-KE-bpKQ")
        XCTAssertEqual(VideoLink.sharedID(from: "A video\nhttps://www.youtube.com/watch?v=aqz-KE-bpKQ\nEnjoy!"), "aqz-KE-bpKQ")
        XCTAssertEqual(VideoLink.sharedID(from: "https://example.com then https://youtu.be/aqz-KE-bpKQ"), "aqz-KE-bpKQ")
        XCTAssertNil(VideoLink.sharedID(from: "https://youtube.com.evil.com/watch?v=aqz-KE-bpKQ"))
        XCTAssertNil(VideoLink.sharedID(from: "No video here"))
    }
    func testIndependentSharesSurviveAndAreAcknowledgedIndividually() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = ShareInbox(directory: directory)
        let reader = ShareInbox(directory: directory)
        XCTAssertTrue(try reader.pending().isEmpty)
        try writer.enqueue(videoID: "aqz-KE-bpKQ")
        try writer.enqueue(videoID: "jfKfPfyJRdk")
        // Sharing the same video twice must not overwrite an unread entry.
        try writer.enqueue(videoID: "aqz-KE-bpKQ")
        let pending = try reader.pending()
        XCTAssertEqual(pending.count, 3)
        XCTAssertEqual(pending.map(\.entry.videoID), ["aqz-KE-bpKQ", "jfKfPfyJRdk", "aqz-KE-bpKQ"])
        try reader.acknowledge(pending[0].url)
        XCTAssertEqual(try reader.pending().count, 2)
        XCTAssertThrowsError(try writer.enqueue(videoID: "../../invalid"))
    }
    func testMalformedEntryDoesNotBlockOtherShares() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let inbox = ShareInbox(directory: directory)
        try inbox.enqueue(videoID: "aqz-KE-bpKQ")
        try Data("broken".utf8).write(to: directory.appendingPathComponent("broken.json"))
        XCTAssertEqual(try inbox.pending().count, 1)
    }
}
