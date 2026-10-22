import XCTest
@testable import PartsCore
final class VideoTests: XCTestCase {
    func testYouTubeLinks() {
        for url in ["https://youtu.be/jfKfPfyJRdk?t=20", "https://www.youtube.com/watch?v=jfKfPfyJRdk&si=abc", "youtube.com/shorts/jfKfPfyJRdk", "https://m.youtube.com/live/jfKfPfyJRdk"] {
            XCTAssertEqual(VideoLink.id(from: url), "jfKfPfyJRdk")
        }
        for url in ["https://youtube.com.evil.com/watch?v=jfKfPfyJRdk", "https://evil.com/jfKfPfyJRdk", "https://youtube.com/watch?v=abc", "javascript:alert(1)", "", "https://youtu.be/%22%3Cscript%3E"] {
            XCTAssertNil(VideoLink.id(from: url))
        }
    }
    func testPartBoundariesAndFinalRemainder() {
        let timeline = PartTimeline(duration: 125)
        XCTAssertEqual(timeline.count, 3)
        XCTAssertEqual(timeline.index(at: 59.99), 0)
        XCTAssertEqual(timeline.index(at: 60), 1)
        XCTAssertEqual(timeline.index(at: 125), 2)
        XCTAssertEqual(timeline.start(2), 120)
        XCTAssertEqual(timeline.end(2), 125)
        XCTAssertEqual(PartTimeline(duration: 120).count, 2)
        XCTAssertEqual(timeline.index(at: -10), 0)
        XCTAssertEqual(PartTimeline(duration: .nan).count, 0)
    }
    func testProgressSurvivesPersistence() throws {
        let video = SavedVideo(id: "jfKfPfyJRdk", title: "Test", duration: 125, position: 74)
        let restored = try JSONDecoder().decode(SavedVideo.self, from: JSONEncoder().encode(video))
        XCTAssertEqual(restored, video)
        XCTAssertEqual(restored.timeline.index(at: restored.position), 1)
    }
}
