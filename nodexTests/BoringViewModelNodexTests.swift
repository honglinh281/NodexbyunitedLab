import CoreGraphics
import XCTest
@testable import nodex

final class BoringViewModelNodexTests: XCTestCase {
    @MainActor
    func testInitialStateUsesClosedNodexMetrics() {
        let viewModel = BoringViewModel()

        XCTAssertEqual(viewModel.nodexMediaPhase, .closed)
        XCTAssertEqual(viewModel.notchState, .closed)
        XCTAssertEqual(viewModel.notchSize, nodexClosedNotchSize)
        XCTAssertEqual(viewModel.closedNotchSize, nodexClosedNotchSize)
        XCTAssertEqual(viewModel.nodexBottomRadius, 8)
    }

    @MainActor
    func testSetNodexMediaPhaseMapsPhaseToSizeRadiusAndNotchState() {
        let viewModel = BoringViewModel()

        assertPhase(.closed, on: viewModel, size: CGSize(width: 286, height: 34), radius: 8, notchState: .closed)
        assertPhase(.hoverCompact, on: viewModel, size: CGSize(width: 312, height: 73), radius: 16, notchState: .closed)
        assertPhase(.expanded, on: viewModel, size: CGSize(width: 364, height: 249), radius: 24, notchState: .open)
        assertPhase(.expandedLyrics, on: viewModel, size: CGSize(width: 364, height: 376), radius: 24, notchState: .open)
    }

    @MainActor
    func testOpenMovesToExpandedAndCloseReturnsToClosed() {
        let viewModel = BoringViewModel()

        viewModel.open()
        XCTAssertEqual(viewModel.nodexMediaPhase, .expanded)
        XCTAssertEqual(viewModel.notchState, .open)
        XCTAssertEqual(viewModel.notchSize, nodexExpandedNotchSize)

        viewModel.close()
        XCTAssertEqual(viewModel.nodexMediaPhase, .closed)
        XCTAssertEqual(viewModel.notchState, .closed)
        XCTAssertEqual(viewModel.notchSize, nodexClosedNotchSize)
        XCTAssertEqual(viewModel.closedNotchSize, nodexClosedNotchSize)
    }

    @MainActor
    func testToggleNodexLyricsCyclesBetweenExpandedStates() {
        let viewModel = BoringViewModel()

        viewModel.toggleNodexLyrics()
        XCTAssertEqual(viewModel.nodexMediaPhase, .expandedLyrics)
        XCTAssertEqual(viewModel.notchState, .open)
        XCTAssertEqual(viewModel.notchSize, nodexExpandedLyricsNotchSize)

        viewModel.toggleNodexLyrics()
        XCTAssertEqual(viewModel.nodexMediaPhase, .expanded)
        XCTAssertEqual(viewModel.notchState, .open)
        XCTAssertEqual(viewModel.notchSize, nodexExpandedNotchSize)

        viewModel.setNodexMediaPhase(.hoverCompact)
        viewModel.toggleNodexLyrics()
        XCTAssertEqual(viewModel.nodexMediaPhase, .expandedLyrics)
        XCTAssertEqual(viewModel.notchState, .open)
    }

    @MainActor
    func testSharingInteractionPreventsCloseUntilFinished() {
        drainSharingInteractions()
        defer { drainSharingInteractions() }

        let viewModel = BoringViewModel()
        viewModel.setNodexMediaPhase(.expandedLyrics)

        SharingStateManager.shared.beginInteraction()
        viewModel.close()

        XCTAssertEqual(viewModel.nodexMediaPhase, .expandedLyrics)
        XCTAssertEqual(viewModel.notchState, .open)

        SharingStateManager.shared.endInteraction()
        viewModel.close()

        XCTAssertEqual(viewModel.nodexMediaPhase, .closed)
        XCTAssertEqual(viewModel.notchState, .closed)
    }

    @MainActor
    func testDropZoneAggregationTracksAnyActiveDropTarget() {
        let viewModel = BoringViewModel()
        XCTAssertFalse(viewModel.anyDropZoneTargeting)

        viewModel.dropZoneTargeting = true
        XCTAssertTrue(viewModel.anyDropZoneTargeting)

        viewModel.dropZoneTargeting = false
        viewModel.dragDetectorTargeting = true
        XCTAssertTrue(viewModel.anyDropZoneTargeting)

        viewModel.dragDetectorTargeting = false
        viewModel.generalDropTargeting = true
        XCTAssertTrue(viewModel.anyDropZoneTargeting)

        viewModel.generalDropTargeting = false
        XCTAssertFalse(viewModel.anyDropZoneTargeting)
    }

    @MainActor
    func testEffectiveClosedHeightHonorsHideOnClosedWithoutScreen() {
        let viewModel = BoringViewModel()

        viewModel.hideOnClosed = true
        XCTAssertEqual(viewModel.effectiveClosedNotchHeight, 0)

        viewModel.hideOnClosed = false
        XCTAssertEqual(viewModel.effectiveClosedNotchHeight, nodexClosedNotchSize.height)
    }

    @MainActor
    private func assertPhase(
        _ phase: NodexMediaPhase,
        on viewModel: BoringViewModel,
        size: CGSize,
        radius: CGFloat,
        notchState: NotchState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        viewModel.setNodexMediaPhase(phase)

        XCTAssertEqual(viewModel.nodexMediaPhase, phase, file: file, line: line)
        XCTAssertEqual(viewModel.notchSize, size, file: file, line: line)
        XCTAssertEqual(viewModel.nodexBottomRadius, radius, file: file, line: line)
        XCTAssertEqual(viewModel.notchState, notchState, file: file, line: line)
    }

    @MainActor
    private func drainSharingInteractions() {
        while SharingStateManager.shared.preventNotchClose {
            SharingStateManager.shared.endInteraction()
        }
    }
}
