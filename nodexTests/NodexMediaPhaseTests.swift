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

    func testTrackPreviewMarqueeMetricsDoNotScrollShortContent() {
        let metrics = NodexTrackPreviewMarqueeMetrics(
            contentWidth: 220,
            viewportWidth: nodexTrackPreviewNotchSize.width,
            centeredContentWidth: 232,
            loopGap: 24,
            scrollSpeed: 32,
            minimumDuration: 1.2
        )

        XCTAssertFalse(metrics.needsScrolling)
        XCTAssertEqual(metrics.startOffset, 0)
        XCTAssertEqual(metrics.endOffset, 0)
    }

    func testTrackPreviewMarqueeMetricsKeepUnmeasuredContentVisibleAndStatic() {
        let metrics = NodexTrackPreviewMarqueeMetrics(
            contentWidth: 0,
            viewportWidth: nodexTrackPreviewNotchSize.width,
            centeredContentWidth: 232,
            longContentStartOffset: 53,
            loopGap: 24,
            scrollSpeed: 32,
            minimumDuration: 1.2
        )

        XCTAssertFalse(metrics.needsScrolling)
        XCTAssertEqual(metrics.startOffset, 0)
        XCTAssertEqual(metrics.endOffset, 0)
    }

    func testTrackPreviewMarqueeMetricsTreatContentBeyondCenteredWidthAsLong() {
        let metrics = NodexTrackPreviewMarqueeMetrics(
            contentWidth: 260,
            viewportWidth: nodexTrackPreviewNotchSize.width,
            centeredContentWidth: 232,
            longContentStartOffset: 53,
            loopGap: 24,
            scrollSpeed: 32,
            minimumDuration: 1.2
        )

        XCTAssertTrue(metrics.needsScrolling)
        XCTAssertEqual(metrics.longContentStartOffset, 53)
        XCTAssertEqual(metrics.startOffset, 53)
        XCTAssertEqual(metrics.travelDistance, 284)
        XCTAssertEqual(metrics.endOffset, -231)
    }

    func testTrackPreviewMarqueeMetricsScrollWholeOverflowingRowFromFadeEdge() {
        let metrics = NodexTrackPreviewMarqueeMetrics(
            contentWidth: 420,
            viewportWidth: nodexTrackPreviewNotchSize.width,
            centeredContentWidth: 232,
            longContentStartOffset: 53,
            loopGap: 24,
            scrollSpeed: 32,
            minimumDuration: 1.2
        )

        XCTAssertTrue(metrics.needsScrolling)
        XCTAssertEqual(metrics.travelDistance, 444)
        XCTAssertEqual(metrics.longContentStartOffset, 53)
        XCTAssertEqual(metrics.startOffset, 53)
        XCTAssertEqual(metrics.endOffset, -391)
        XCTAssertEqual(metrics.duration, 13.875)
    }

    func testTrackPreviewMarqueeMetricsRespectMinimumDuration() {
        let metrics = NodexTrackPreviewMarqueeMetrics(
            contentWidth: 40,
            viewportWidth: 10,
            centeredContentWidth: 0,
            longContentStartOffset: 53,
            loopGap: 0,
            scrollSpeed: 1_000,
            minimumDuration: 1.2
        )

        XCTAssertTrue(metrics.needsScrolling)
        XCTAssertEqual(metrics.duration, 1.2)
    }
}
