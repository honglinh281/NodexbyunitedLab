//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI
import SwiftUIIntrospect

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared

    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var brightnessManager = BrightnessManager.shared
    @ObservedObject var volumeManager = VolumeManager.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State private var gestureProgress: CGFloat = .zero

    @State private var haptics: Bool = false

    @Namespace var albumArtNamespace

    @Default(.useMusicVisualizer) var useMusicVisualizer

    @Default(.showNotHumanFace) var showNotHumanFace

    // Shared interactive spring for movement/resizing to avoid conflicting animations
    private let animationSpring = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: 0,
            bottomCornerRadius: vm.nodexBottomRadius
        )
    }

    private var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
        {
            chinWidth = 640
        } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)
        } else if !coordinator.expandingView.show && vm.notchState == .closed
            && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace]
            && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)
        }

        return chinWidth
    }

    var body: some View {
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            NotchLayout()
                .frame(width: vm.notchSize.width, height: vm.notchSize.height, alignment: .top)
                .background(.black)
                .clipShape(currentNotchShape)
                .shadow(
                    color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                        ? .black.opacity(0.7) : .clear,
                    radius: vm.notchState == .open ? 10 : 4,
                    y: 6
                )
                    .conditionalModifier(true) { view in
                        let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
                        let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
                        
                        return view
                            .animation(vm.notchState == .open ? openAnimation : closeAnimation, value: vm.nodexMediaPhase)
                            .animation(.smooth(duration: 0.22), value: isHovering)
                            .animation(.smooth, value: gestureProgress)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        doOpen()
                    }
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(Defaults[.closeGestureEnabled] && Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .up) { translation, phase in
                                handleUpGesture(translation: translation, phase: phase)
                            }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                        if vm.notchState == .open && !isHovering && !vm.isBatteryPopoverActive {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.vm.notchState == .open && !self.isHovering && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        if newState == .closed && isHovering {
                            withAnimation {
                                isHovering = false
                            }
                        }
                    }
                    .onChange(of: vm.isBatteryPopoverActive) {
                        if !vm.isBatteryPopoverActive && !isHovering && vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if !self.vm.isBatteryPopoverActive && !self.isHovering && self.vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            DispatchQueue.main.async {
                                SettingsWindowController.shared.showWindow()
                            }
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                        //                    Button("Edit") { // Doesnt work....
                        //                        let dn = DynamicNotch(content: EditPanelView())
                        //                        dn.toggle()
                        //                    }
                        //                    .keyboardShortcut("E", modifiers: .command)
                    }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)
        .compositingGroup()
        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(.smooth, value: gestureProgress)
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
        .onAppear {
            vm.syncNodexPlaybackState(isPlaying: musicManager.isPlaying)
        }
        .onChange(of: musicManager.isPlaying) { _, isPlaying in
            withAnimation(animationSpring) {
                vm.syncNodexPlaybackState(isPlaying: isPlaying)
            }
        }
        .onReceive(musicManager.$trackChangeToken.dropFirst()) { _ in
            withAnimation(animationSpring) {
                vm.showNodexTrackPreview(isPlaying: musicManager.isPlaying)
            }
        }
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if vm.notchState == .closed {
                    coordinator.currentView = .shelf
                    doOpen()
                }
                return
            }

            anyDropDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if vm.dropEvent {
                    vm.dropEvent = false
                    return
                }

                vm.dropEvent = false
                if !SharingStateManager.shared.preventNotchClose {
                    vm.close()
                }
            }
        }
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        if coordinator.helloAnimationRunning {
            HelloAnimation(onFinish: {
                vm.closeHello()
            })
            .frame(width: vm.notchSize.width, height: vm.notchSize.height)
        } else {
            NodexMediaSurface(
                albumArtNamespace: albumArtNamespace,
                haptics: $haptics
            )
            .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
            .transition(
                .scale(scale: 0.96, anchor: .top)
                .combined(with: .opacity)
            )
        }
    }

    @ViewBuilder
    func BoringFaceAnimation() -> some View {
        HStack {
            HStack {
                Rectangle()
                    .fill(.clear)
                    .frame(
                        width: max(0, vm.effectiveClosedNotchHeight - 12),
                        height: max(0, vm.effectiveClosedNotchHeight - 12)
                    )
                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 20)
                MinimalFaceFeatures()
            }
        }.frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func MusicLiveActivity() -> some View {
        HStack {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .clipped()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed)
                )
                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                .frame(
                    width: max(0, vm.effectiveClosedNotchHeight - 12),
                    height: max(0, vm.effectiveClosedNotchHeight - 12)
                )

            Rectangle()
                .fill(.black)
                .overlay(
                    HStack(alignment: .top) {
                        if coordinator.expandingView.show
                            && coordinator.expandingView.type == .music
                        {
                            MarqueeText(
                                .constant(musicManager.songTitle),
                                textColor: Defaults[.coloredSpectrogram]
                                    ? Color(nsColor: musicManager.avgColor) : Color.gray,
                                minDuration: 0.4,
                                frameWidth: 100
                            )
                            .opacity(
                                (coordinator.expandingView.show
                                    && Defaults[.sneakPeekStyles] == .inline)
                                    ? 1 : 0
                            )
                            Spacer(minLength: vm.closedNotchSize.width)
                            // Song Artist
                            Text(musicManager.artistName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(
                                    Defaults[.coloredSpectrogram]
                                        ? Color(nsColor: musicManager.avgColor)
                                        : Color.gray
                                )
                                .opacity(
                                    (coordinator.expandingView.show
                                        && coordinator.expandingView.type == .music
                                        && Defaults[.sneakPeekStyles] == .inline)
                                        ? 1 : 0
                                )
                        }
                    }
                )
                .frame(
                    width: (coordinator.expandingView.show
                        && coordinator.expandingView.type == .music
                        && Defaults[.sneakPeekStyles] == .inline)
                        ? 380
                        : vm.closedNotchSize.width
                            + -cornerRadiusInsets.closed.top
                )

            HStack {
                if useMusicVisualizer {
                    Rectangle()
                        .fill(
                            Defaults[.coloredSpectrogram]
                                ? Color(nsColor: musicManager.avgColor).gradient
                                : Color.gray.gradient
                        )
                        .frame(width: 50, alignment: .center)
                        .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                        .mask {
                            AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                                .frame(width: 16, height: 12)
                        }
                } else {
                    LottieAnimationContainer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(
                width: max(
                    0,
                    vm.effectiveClosedNotchHeight - 12
                        + gestureProgress / 2
                ),
                height: max(
                    0,
                    vm.effectiveClosedNotchHeight - 12
                ),
                alignment: .center
            )
        }
        .frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    var dragDetector: some View {
        EmptyView()
    }

    private func doOpen() {
        withAnimation(animationSpring) {
            vm.open()
        }
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        hoverTask?.cancel()
        
        if hovering {
            let wasTrackPreview = vm.nodexMediaPhase == .trackPreview
            withAnimation(animationSpring) {
                isHovering = true
                vm.cancelNodexTrackPreview(returnToBase: true, isPlaying: musicManager.isPlaying)
            }
            
            if vm.notchState == .closed && Defaults[.enableHaptics] {
                haptics.toggle()
            }
            
            guard vm.notchState == .closed else { return }

            if wasTrackPreview {
                doOpen()
                return
            }
            
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering else { return }
                    
                    self.doOpen()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    withAnimation(animationSpring) {
                        self.isHovering = false
                    }
                    
                    if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                        self.vm.close()
                    }
                }
            }
        }
    }

    // MARK: - Gesture Handling

    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }

        if phase == .ended {
            withAnimation(animationSpring) { gestureProgress = .zero }
            return
        }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }

        if translation > Defaults[.gestureSensitivity] {
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
            doOpen()
        }
    }

    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .open && !vm.isHoveringCalendar else { return }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
        }

        if phase == .ended {
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {
            withAnimation(animationSpring) {
                isHovering = false
            }
            if !SharingStateManager.shared.preventNotchClose { 
                gestureProgress = .zero
                vm.close()
            }

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }
}

private struct NodexMediaSurface: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var musicManager = MusicManager.shared
    let albumArtNamespace: Namespace.ID
    @Binding var haptics: Bool

    @State private var progressValue: Double = 0
    @State private var isDraggingProgress = false
    @State private var lastDragged: Date = .distantPast

    private var artistLine: String {
        if musicManager.artistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return musicManager.bundleIdentifier ?? "Now Playing"
        }
        return musicManager.artistName
    }

    private var compactLine: String {
        let title = musicManager.songTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = artistLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return artist }
        return "\(title) • \(artist)"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black

            switch vm.nodexMediaPhase {
            case .idle:
                idleContent
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
            case .playingBase:
                playingBaseContent
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
            case .trackPreview:
                trackPreviewContent
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            case .controls:
                expandedContent(showLyrics: false)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            case .lyrics:
                expandedContent(showLyrics: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
        .clipped()
        .compositingGroup()
    }

    private var idleContent: some View {
        ZStack(alignment: .topLeading) {
            NodexPixelBlob()
                .frame(width: 28, height: 28)
                .position(x: 20, y: 17)
        }
        .frame(width: nodexClosedNotchSize.width, height: nodexClosedNotchSize.height)
    }

    private var playingBaseContent: some View {
        ZStack(alignment: .topLeading) {
            decorativeNotes(x: 26, y: -3)

            albumArt(size: 24, radius: 4)
                .position(x: 18, y: 17)

            NodexWaveView(isPlaying: $musicManager.isPlaying, tint: waveTint)
                .frame(width: 24, height: 24)
                .position(x: 266, y: 28)
        }
        .frame(width: nodexClosedNotchSize.width, height: nodexClosedNotchSize.height)
    }

    private var trackPreviewContent: some View {
        ZStack(alignment: .topLeading) {
            decorativeNotes(x: 26, y: -3)

            albumArt(size: 24, radius: 4)
                .position(x: 20, y: 19)

            NodexWaveView(isPlaying: $musicManager.isPlaying, tint: waveTint)
                .frame(width: 24, height: 24)
                .position(x: 292, y: 43)

            HStack(spacing: 2) {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))

                Text("Now playing:")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(Color(red: 65.0 / 255.0, green: 217.0 / 255.0, blue: 117.0 / 255.0))
                    .fixedSize()

                MarqueeText(
                    .constant(compactLine),
                    font: .system(size: 15, weight: .regular),
                    nsFont: .body,
                    textColor: .white.opacity(0.64),
                    minDuration: 1.2,
                    frameWidth: 215
                )
            }
            .frame(width: 272, height: 18, alignment: .leading)
            .position(x: 176, y: 54)

            fadeEdge(width: 53, leading: true)
                .frame(height: 18)
                .position(x: 26.5, y: 54)
            fadeEdge(width: 53, leading: false)
                .frame(height: 18)
                .position(x: 285.5, y: 54)
        }
        .frame(width: nodexTrackPreviewNotchSize.width, height: nodexTrackPreviewNotchSize.height)
    }

    private func expandedContent(showLyrics: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            decorativeNotes(x: 61, y: 14)

            titleContainer
                .frame(width: 320, height: 48)
                .position(x: 182, y: 46)

            if showLyrics {
                lyricsBlock
                    .frame(width: 320, height: 91)
                    .position(x: 182, y: 151.5)
            }

            mediaControls
                .frame(width: 320, height: 71)
                .position(x: 182, y: showLyrics ? 268.5 : 141.5)

            bottomMenu
                .frame(width: 364, height: 48)
                .position(x: 182, y: showLyrics ? 352 : 225)
        }
        .frame(width: showLyrics ? nodexLyricsNotchSize.width : nodexControlsNotchSize.width,
               height: showLyrics ? nodexLyricsNotchSize.height : nodexControlsNotchSize.height)
    }

    private var titleContainer: some View {
        HStack(alignment: .bottom, spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
                albumArt(size: 42, radius: 10)
                    .padding(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                AngularGradient(
                                    colors: [waveTint.opacity(0.9), .white.opacity(0.18), waveTint.opacity(0.35), waveTint.opacity(0.9)],
                                    center: .center
                                ),
                                lineWidth: 1
                            )
                    )

                AppIcon(for: musicManager.bundleIdentifier ?? "com.apple.Music")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
                    .padding(2)
                    .background(Circle().fill(.black))
                    .offset(x: 2, y: 2)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(
                    $musicManager.songTitle,
                    font: .system(size: 16, weight: .medium),
                    nsFont: .headline,
                    textColor: .white,
                    minDuration: 1.4,
                    frameWidth: 222
                )
                .frame(width: 222, height: 19, alignment: .leading)

                Text(artistLine)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
                    .frame(width: 222, alignment: .leading)
            }
            .frame(width: 222, height: 37, alignment: .leading)

            Button {
                triggerHaptic()
                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.82, blendDuration: 0)) {
                    vm.toggleNodexLyrics()
                }
            } label: {
                Image(systemName: vm.nodexMediaPhase == .lyrics ? "text.quote" : "captions.bubble")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
    }

    private var lyricsBlock: some View {
        let lines = lyricLines()

        return ZStack(alignment: .top) {
            VStack(alignment: .center, spacing: 8) {
                Text(lines.current)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(width: 320, alignment: .center)

                Text(lines.next)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(width: 320, alignment: .center)

                Text(lines.after)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.32))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(width: 320, alignment: .center)
            }
            .padding(.top, 12)

            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 320, height: 56)
            .offset(y: 40)
            .allowsHitTesting(false)
        }
    }

    private var mediaControls: some View {
        VStack(spacing: 15) {
            HStack(spacing: 10) {
                NodexIconButton(systemName: "shuffle", isActive: musicManager.isShuffled) {
                    triggerHaptic()
                    MusicManager.shared.toggleShuffle()
                }
                .opacity(0.48)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    NodexIconButton(systemName: "backward.fill", hasBackground: true) {
                        triggerHaptic()
                        MusicManager.shared.previousTrack()
                    }

                    NodexIconButton(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill", hasBackground: true) {
                        triggerHaptic()
                        MusicManager.shared.togglePlay()
                    }

                    NodexIconButton(systemName: "forward.fill", hasBackground: true) {
                        triggerHaptic()
                        MusicManager.shared.nextTrack()
                    }
                }

                Spacer(minLength: 0)

                NodexIconButton(systemName: repeatIcon, isActive: musicManager.repeatMode != .off) {
                    triggerHaptic()
                    MusicManager.shared.toggleRepeat()
                }
                .opacity(0.48)
            }
            .frame(height: 40)

            TimelineView(.animation(minimumInterval: musicManager.playbackRate > 0 ? 0.1 : nil)) { timeline in
                let position = estimatedPosition(at: timeline.date)
                HStack(spacing: 10) {
                    Text(timeString(from: isDraggingProgress ? progressValue : position))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .frame(width: 26, alignment: .leading)

                    NodexProgressBar(
                        value: isDraggingProgress ? progressValue : position,
                        duration: max(musicManager.songDuration, 1),
                        tint: .white,
                        isDragging: $isDraggingProgress,
                        onChange: { newValue in
                            progressValue = newValue
                        },
                        onCommit: { newValue in
                            lastDragged = Date()
                            MusicManager.shared.seek(to: newValue)
                        }
                    )
                    .frame(width: 248, height: 10)

                    Text(timeString(from: musicManager.songDuration))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.48))
                        .monospacedDigit()
                        .frame(width: 26, alignment: .trailing)
                }
                .frame(height: 16)
            }
        }
    }

    private var bottomMenu: some View {
        HStack(spacing: 10) {
            NodexMenuButton(systemName: "music.note", isActive: vm.nodexMediaPhase == .controls) {
                triggerHaptic()
                withAnimation(.smooth(duration: 0.22)) {
                    vm.setNodexMediaPhase(.controls)
                }
            }
            NodexMenuButton(systemName: "text.quote", isActive: vm.nodexMediaPhase == .lyrics) {
                triggerHaptic()
                withAnimation(.smooth(duration: 0.22)) {
                    vm.setNodexMediaPhase(.lyrics)
                }
            }
            NodexMenuButton(systemName: "list.bullet") {
                triggerHaptic()
            }
            NodexMenuButton(systemName: "heart") {
                triggerHaptic()
                if musicManager.canFavoriteTrack {
                    MusicManager.shared.toggleFavoriteTrack()
                }
            }
            NodexMenuButton(systemName: "gearshape") {
                triggerHaptic()
                SettingsWindowController.shared.showWindow()
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 9)
        .frame(width: 364, height: 48)
        .background(.white.opacity(0.03))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(height: 1)
        }
    }

    private func albumArt(size: CGFloat, radius: CGFloat) -> some View {
        Image(nsImage: musicManager.albumArt)
            .resizable()
            .aspectRatio(1, contentMode: .fill)
            .matchedGeometryEffect(id: "nodexAlbumArt", in: albumArtNamespace)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var waveTint: Color {
        Defaults[.coloredSpectrogram]
            ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.65)
            : .white
    }

    private var repeatIcon: String {
        switch musicManager.repeatMode {
        case .one:
            return "repeat.1"
        case .all, .off:
            return "repeat"
        }
    }

    private func decorativeNotes(x: CGFloat, y: CGFloat) -> some View {
        ZStack {
            Image(systemName: "music.note")
                .font(.system(size: 5, weight: .semibold))
                .opacity(1)
                .offset(x: 2, y: 6)
            Image(systemName: "music.note")
                .font(.system(size: 4, weight: .semibold))
                .opacity(1)
                .offset(x: 0, y: 3)
            Image(systemName: "music.note")
                .font(.system(size: 5, weight: .semibold))
                .opacity(0.8)
                .offset(x: 6, y: 0)
            Image(systemName: "music.note")
                .font(.system(size: 3, weight: .semibold))
                .opacity(0.5)
                .offset(x: 9, y: 5)
        }
        .foregroundStyle(.white)
        .frame(width: 14, height: 14)
        .position(x: x + 7, y: y + 7)
        .allowsHitTesting(false)
    }

    private func fadeEdge(width: CGFloat, leading: Bool) -> some View {
        LinearGradient(
            colors: leading ? [.black, .black.opacity(0)] : [.black.opacity(0), .black],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width)
        .allowsHitTesting(false)
    }

    private func estimatedPosition(at date: Date) -> Double {
        guard !isDraggingProgress else { return progressValue }
        if date.timeIntervalSince(lastDragged) < 0.25 { return progressValue }
        return min(max(MusicManager.shared.estimatedPlaybackPosition(at: date), 0), max(musicManager.songDuration, 0))
    }

    private func lyricLines() -> (current: String, next: String, after: String) {
        let elapsed = MusicManager.shared.estimatedPlaybackPosition(at: Date())

        if !musicManager.syncedLyrics.isEmpty {
            let sorted = musicManager.syncedLyrics.sorted { $0.time < $1.time }
            let currentIndex = sorted.lastIndex(where: { $0.time <= elapsed }) ?? 0
            let current = sorted[safe: currentIndex]?.text ?? "Lyrics"
            let next = sorted[safe: currentIndex + 1]?.text ?? ""
            let after = sorted[safe: currentIndex + 2]?.text ?? ""
            return (current, next, after)
        }

        let lines = musicManager.currentLyrics
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !lines.isEmpty {
            return (
                lines[safe: 0] ?? "Lyrics",
                lines[safe: 1] ?? "",
                lines[safe: 2] ?? ""
            )
        }

        return (
            musicManager.isFetchingLyrics ? "Loading lyrics..." : "Lyrics unavailable",
            musicManager.songTitle,
            artistLine
        )
    }

    private func timeString(from seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    private func triggerHaptic() {
        if Defaults[.enableHaptics] {
            haptics.toggle()
        }
    }
}

private struct NodexPixelBlob: View {
    private let pixelCount = 20
    private let cellRatio = 4.0 / 6.0
    private let foreground = Color(red: 1.0, green: 44.0 / 255.0, blue: 247.0 / 255.0)
    private let background = Color(red: 13.0 / 255.0, green: 0, blue: 16.0 / 255.0)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let side = min(size.width, size.height)
                let step = side / CGFloat(pixelCount)
                let cell = step * CGFloat(cellRatio)
                let origin = CGPoint(
                    x: (size.width - side) / 2,
                    y: (size.height - side) / 2
                )
                let t = timeline.date.timeIntervalSinceReferenceDate

                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background.opacity(0.55)))

                for iy in 0..<pixelCount {
                    for ix in 0..<pixelCount {
                        let value = max(0, min(1, blobRule(
                            x: Double(ix) / Double(pixelCount - 1),
                            y: Double(iy) / Double(pixelCount - 1),
                            time: t
                        )))

                        guard value > 0 else { continue }

                        let rect = CGRect(
                            x: origin.x + CGFloat(ix) * step,
                            y: origin.y + CGFloat(iy) * step,
                            width: cell,
                            height: cell
                        )
                        context.fill(Path(rect), with: .color(foreground.opacity(value)))
                    }
                }
            }
        }
        .drawingGroup(opaque: false)
    }

    private func blobRule(x: Double, y: Double, time: Double) -> Double {
        let a = x - 0.5
        let c = y - 0.5
        let angle = atan2(c, a)
        let distance = sqrt(a * a + c * c)
        let wave = 0.28
            + sin(angle * 3 + time) * 0.07
            + sin(angle * 5 - time * 0.9) * 0.04

        if distance > wave + 0.07 {
            return 0
        }

        if distance > wave {
            return (1 - (distance - wave) / 0.07) * 0.55
        }

        return 0.55 + (1 - distance / max(wave, 0.0001)) * 0.45
    }
}

private struct NodexIconButton: View {
    let systemName: String
    var isActive: Bool = false
    var hasBackground: Bool = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? Color.effectiveAccent : .white)
                .contentTransition(.symbolEffect)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(hasBackground ? .white.opacity(isHovering ? 0.14 : 0.08) : .clear)
                )
                .scaleEffect(isHovering ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.18)) {
                isHovering = hovering
            }
        }
    }
}

private struct NodexMenuButton: View {
    let systemName: String
    var isActive: Bool = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? Color.effectiveAccent : .white.opacity(isHovering ? 0.86 : 0.48))
                .frame(width: 42, height: 30)
                .background(
                    Capsule()
                        .fill(isActive ? Color.effectiveAccent.opacity(0.16) : .white.opacity(isHovering ? 0.08 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.18)) {
                isHovering = hovering
            }
        }
    }
}

private struct NodexWaveView: View {
    @Binding var isPlaying: Bool
    let tint: Color

    var body: some View {
        tint
            .mask {
                AudioSpectrumView(isPlaying: $isPlaying)
                    .frame(width: 16, height: 14)
            }
            .frame(width: 24, height: 24)
    }
}

private struct NodexProgressBar: View {
    let value: Double
    let duration: Double
    let tint: Color
    @Binding var isDragging: Bool
    let onChange: (Double) -> Void
    let onCommit: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let clampedDuration = max(duration, 1)
            let progress = min(max(value / clampedDuration, 0), 1)
            let height: CGFloat = isDragging ? 9 : 6

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(height: height)

                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * progress), height: height)
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let ratio = min(max(gesture.location.x / max(geo.size.width, 1), 0), 1)
                        onChange(Double(ratio) * clampedDuration)
                    }
                    .onEnded { gesture in
                        let ratio = min(max(gesture.location.x / max(geo.size.width, 1), 0), 1)
                        let committed = Double(ratio) * clampedDuration
                        onChange(committed)
                        onCommit(committed)
                        isDragging = false
                    }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDragging)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct FullScreenDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        isTargeted = true
    }

    func dropExited(info _: DropInfo) {
        isTargeted = false
    }

    func performDrop(info _: DropInfo) -> Bool {
        isTargeted = false
        onDrop()
        return true
    }

}

struct GeneralDropTargetDelegate: DropDelegate {
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        return false
    }
}

#Preview {
    let vm = BoringViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
