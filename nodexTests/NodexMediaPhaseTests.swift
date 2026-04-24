import CoreGraphics
import XCTest
@testable import nodex

final class NodexMediaPhaseTests: XCTestCase {
    func testFigmaPhaseMetrics() {
        let expectations: [(phase: NodexMediaPhase, size: CGSize, radius: CGFloat, state: NotchState)] = [
            (.idle, CGSize(width: 286, height: 34), 8, .closed),
            (.playingBase, CGSize(width: 286, height: 34), 8, .closed),
            (.trackPreview, CGSize(width: 312, height: 73), 16, .closed),
            (.controls, CGSize(width: 364, height: 249), 24, .open),
            (.lyrics, CGSize(width: 364, height: 376), 24, .open),
        ]

        XCTAssertEqual(NodexMediaPhase.allCases.count, expectations.count)

        for expected in expectations {
            XCTAssertEqual(expected.phase.notchSize, expected.size)
            XCTAssertEqual(expected.phase.bottomRadius, expected.radius)
            XCTAssertEqual(expected.phase.notchState, expected.state)
        }
    }

    func testWindowSizeAccommodatesLargestPhaseAndShadowPadding() {
        XCTAssertEqual(openNotchSize, nodexLyricsNotchSize)
        XCTAssertEqual(windowSize.width, nodexLyricsNotchSize.width)
        XCTAssertEqual(windowSize.height, nodexLyricsNotchSize.height + shadowPadding)
    }

    @MainActor
    func testClosedNotchSizeIsNodexClosedSizeForAnyScreen() {
        XCTAssertEqual(getClosedNotchSize(), nodexClosedNotchSize)
        XCTAssertEqual(getClosedNotchSize(screenUUID: "missing-screen"), nodexClosedNotchSize)
    }

    func testTrackChangeGateSkipsFirstPlayableTrackThenEmitsSubsequentContentChanges() {
        var gate = NodexTrackChangeGate()

        XCTAssertFalse(gate.shouldEmitTrackChange(
            isPlaying: true,
            title: "First",
            artist: "Artist",
            hasContentChange: true
        ))
        XCTAssertTrue(gate.hasObservedPlayableTrack)

        XCTAssertFalse(gate.shouldEmitTrackChange(
            isPlaying: true,
            title: "First",
            artist: "Artist",
            hasContentChange: false
        ))

        XCTAssertTrue(gate.shouldEmitTrackChange(
            isPlaying: true,
            title: "Second",
            artist: "Artist",
            hasContentChange: true
        ))
    }

    func testTrackChangeGateIgnoresPausedOrIncompleteMetadata() {
        var gate = NodexTrackChangeGate()

        XCTAssertFalse(gate.shouldEmitTrackChange(
            isPlaying: false,
            title: "Paused",
            artist: "Artist",
            hasContentChange: true
        ))
        XCTAssertFalse(gate.hasObservedPlayableTrack)

        XCTAssertFalse(gate.shouldEmitTrackChange(
            isPlaying: true,
            title: "",
            artist: "Artist",
            hasContentChange: true
        ))
        XCTAssertFalse(gate.hasObservedPlayableTrack)
    }
}
