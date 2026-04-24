import CoreGraphics
import XCTest
@testable import nodex

final class BoringViewModelNodexTests: XCTestCase {
    @MainActor
    func testInitialStateUsesClosedNodexMetrics() {
        let viewModel = BoringViewModel()

        XCTAssertEqual(viewModel.nodexMediaPhase, .idle)
        XCTAssertEqual(viewModel.notchState, .closed)
        XCTAssertEqual(viewModel.notchSize, nodexClosedNotchSize)
        XCTAssertEqual(viewModel.closedNotchSize, nodexClosedNotchSize)
        XCTAssertEqual(viewModel.nodexBottomRadius, 8)
    }

    @MainActor
    func testSetNodexMediaPhaseMapsPhaseToSizeRadiusAndNotchState() {
        let viewModel = BoringViewModel()

        assertPhase(.idle, on: viewModel, size: CGSize(width: 286, height: 34), radius: 8, notchState: .closed)
        assertPhase(.playingBase, on: viewModel, size: CGSize(width: 286, height: 34), radius: 8, notchState: .closed)
        assertPhase(.trackPreview, on: viewModel, size: CGSize(width: 312, height: 73), radius: 16, notchState: .closed)
        assertPhase(.controls, on: viewModel, size: CGSize(width: 364, height: 249), radius: 24, notchState: .open)
        assertPhase(.lyrics, on: viewModel, size: CGSize(width: 364, height: 376), radius: 24, notchState: .open)
    }

    @MainActor
    func testOpenMovesToControlsAndCloseReturnsToPlaybackBaseOrIdle() {
        let viewModel = BoringViewModel()

        viewModel.open()
        XCTAssertEqual(viewModel.nodexMediaPhase, .controls)
        XCTAssertEqual(viewModel.notchState, .open)
        XCTAssertEqual(viewModel.notchSize, nodexControlsNotchSize)

        viewModel.close(isPlaying: true)
        XCTAssertEqual(viewModel.nodexMediaPhase, .playingBase)
        XCTAssertEqual(viewModel.notchState, .closed)
        XCTAssertEqual(viewModel.notchSize, nodexClosedNotchSize)
        XCTAssertEqual(viewModel.closedNotchSize, nodexClosedNotchSize)

        viewModel.open()
        viewModel.close(isPlaying: false)
        XCTAssertEqual(viewModel.nodexMediaPhase, .idle)
        XCTAssertEqual(viewModel.notchState, .closed)
    }

    @MainActor
    func testSyncPlaybackStateUsesIdleForNoMusicAndPlayingBaseForPlayback() {
        let viewModel = BoringViewModel()

        viewModel.syncNodexPlaybackState(isPlaying: false)
        XCTAssertEqual(viewModel.nodexMediaPhase, .idle)
        XCTAssertEqual(viewModel.notchState, .closed)

        viewModel.syncNodexPlaybackState(isPlaying: true)
        XCTAssertEqual(viewModel.nodexMediaPhase, .playingBase)
        XCTAssertEqual(viewModel.notchState, .closed)
    }

    @MainActor
    func testToggleNodexLyricsCyclesBetweenControlsAndLyrics() {
        let viewModel = BoringViewModel()

        viewModel.setNodexMediaPhase(.controls)
        viewModel.toggleNodexLyrics()
        XCTAssertEqual(viewModel.nodexMediaPhase, .lyrics)
        XCTAssertEqual(viewModel.notchState, .open)
        XCTAssertEqual(viewModel.notchSize, nodexLyricsNotchSize)

        viewModel.toggleNodexLyrics()
        XCTAssertEqual(viewModel.nodexMediaPhase, .controls)
        XCTAssertEqual(viewModel.notchState, .open)
        XCTAssertEqual(viewModel.notchSize, nodexControlsNotchSize)

        viewModel.setNodexMediaPhase(.trackPreview)
        viewModel.toggleNodexLyrics()
        XCTAssertEqual(viewModel.nodexMediaPhase, .trackPreview)
        XCTAssertEqual(viewModel.notchState, .closed)
    }

    @MainActor
    func testTrackPreviewReturnsToPlayingBaseAfterDuration() async {
        let viewModel = BoringViewModel()
        viewModel.nodexTrackPreviewDuration = .milliseconds(10)

        viewModel.showNodexTrackPreview(isPlaying: true)
        XCTAssertEqual(viewModel.nodexMediaPhase, .trackPreview)
        XCTAssertEqual(viewModel.notchSize, nodexTrackPreviewNotchSize)

        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(viewModel.nodexMediaPhase, .playingBase)
        XCTAssertEqual(viewModel.notchState, .closed)
    }

    @MainActor
    func testTrackPreviewDoesNotShowWhenNotPlaying() {
        let viewModel = BoringViewModel()

        viewModel.showNodexTrackPreview(isPlaying: false)

        XCTAssertEqual(viewModel.nodexMediaPhase, .idle)
        XCTAssertEqual(viewModel.notchState, .closed)
    }

    @MainActor
    func testOpenCancelsTrackPreviewTimerAndKeepsControlsOpen() async {
        let viewModel = BoringViewModel()
        viewModel.nodexTrackPreviewDuration = .milliseconds(20)

        viewModel.showNodexTrackPreview(isPlaying: true)
        XCTAssertEqual(viewModel.nodexMediaPhase, .trackPreview)

        viewModel.open()
        XCTAssertEqual(viewModel.nodexMediaPhase, .controls)

        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(viewModel.nodexMediaPhase, .controls)
        XCTAssertEqual(viewModel.notchState, .open)
    }

    @MainActor
    func testClosingControlsAndLyricsReturnsToPlaybackBaseOrIdle() {
        let viewModel = BoringViewModel()

        viewModel.setNodexMediaPhase(.controls)
        viewModel.close(isPlaying: true)
        XCTAssertEqual(viewModel.nodexMediaPhase, .playingBase)

        viewModel.setNodexMediaPhase(.lyrics)
        viewModel.close(isPlaying: false)
        XCTAssertEqual(viewModel.nodexMediaPhase, .idle)
    }

    @MainActor
    func testSharingInteractionPreventsCloseUntilFinished() {
        drainSharingInteractions()
        defer { drainSharingInteractions() }

        let viewModel = BoringViewModel()
        viewModel.setNodexMediaPhase(.lyrics)

        SharingStateManager.shared.beginInteraction()
        viewModel.close(isPlaying: false)

        XCTAssertEqual(viewModel.nodexMediaPhase, .lyrics)
        XCTAssertEqual(viewModel.notchState, .open)

        SharingStateManager.shared.endInteraction()
        viewModel.close(isPlaying: false)

        XCTAssertEqual(viewModel.nodexMediaPhase, .idle)
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
