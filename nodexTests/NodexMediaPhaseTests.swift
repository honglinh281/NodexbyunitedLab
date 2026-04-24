import CoreGraphics
import XCTest
@testable import nodex

final class NodexMediaPhaseTests: XCTestCase {
    func testFigmaPhaseMetrics() {
        let expectations: [(phase: NodexMediaPhase, size: CGSize, radius: CGFloat, state: NotchState)] = [
            (.closed, CGSize(width: 286, height: 34), 8, .closed),
            (.hoverCompact, CGSize(width: 312, height: 73), 16, .closed),
            (.expanded, CGSize(width: 364, height: 249), 24, .open),
            (.expandedLyrics, CGSize(width: 364, height: 376), 24, .open),
        ]

        XCTAssertEqual(NodexMediaPhase.allCases.count, expectations.count)

        for expected in expectations {
            XCTAssertEqual(expected.phase.notchSize, expected.size)
            XCTAssertEqual(expected.phase.bottomRadius, expected.radius)
            XCTAssertEqual(expected.phase.notchState, expected.state)
        }
    }

    func testWindowSizeAccommodatesLargestPhaseAndShadowPadding() {
        XCTAssertEqual(openNotchSize, nodexExpandedLyricsNotchSize)
        XCTAssertEqual(windowSize.width, nodexExpandedLyricsNotchSize.width)
        XCTAssertEqual(windowSize.height, nodexExpandedLyricsNotchSize.height + shadowPadding)
    }

    @MainActor
    func testClosedNotchSizeIsNodexClosedSizeForAnyScreen() {
        XCTAssertEqual(getClosedNotchSize(), nodexClosedNotchSize)
        XCTAssertEqual(getClosedNotchSize(screenUUID: "missing-screen"), nodexClosedNotchSize)
    }
}
