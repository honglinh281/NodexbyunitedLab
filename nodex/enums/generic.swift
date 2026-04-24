//
//  generic.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Foundation
import Defaults
import CoreGraphics

public enum Style {
    case notch
    case floating
}

public enum ContentType: Int, Codable, Hashable, Equatable {
    case normal
    case menu
    case settings
}

public enum NotchState: Equatable {
    case closed
    case open
}

public enum NotchViews {
    case home
    case shelf
}

public enum NodexMediaPhase: CaseIterable, Equatable {
    case idle
    case playingBase
    case trackPreview
    case controls
    case lyrics

    var notchSize: CGSize {
        switch self {
        case .idle, .playingBase:
            return nodexClosedNotchSize
        case .trackPreview:
            return nodexTrackPreviewNotchSize
        case .controls:
            return nodexControlsNotchSize
        case .lyrics:
            return nodexLyricsNotchSize
        }
    }

    var bottomRadius: CGFloat {
        switch self {
        case .idle, .playingBase:
            return 8
        case .trackPreview:
            return 16
        case .controls, .lyrics:
            return 24
        }
    }

    var notchState: NotchState {
        switch self {
        case .idle, .playingBase, .trackPreview:
            return .closed
        case .controls, .lyrics:
            return .open
        }
    }

    var isOpenPresentation: Bool {
        notchState == .open
    }
}

enum SettingsEnum {
    case general
    case about
    case charge
    case download
    case mediaPlayback
    case hud
    case shelf
    case extensions
}

enum DownloadIndicatorStyle: String, Defaults.Serializable {
    case progress = "Progress"
    case percentage = "Percentage"
}

enum DownloadIconStyle: String, Defaults.Serializable {
    case onlyAppIcon = "Only app icon"
    case onlyIcon = "Only download icon"
    case iconAndAppIcon = "Icon and app icon"
}

enum MirrorShapeEnum: String, Defaults.Serializable {
    case rectangle = "Rectangular"
    case circle = "Circular"
}

enum WindowHeightMode: String, Defaults.Serializable {
    case matchMenuBar = "Match menubar height"
    case matchRealNotchSize = "Match real notch height"
    case custom = "Custom height"
}

enum SliderColorEnum: String, CaseIterable, Defaults.Serializable {
    case white = "White"
    case albumArt = "Match album art"
    case accent = "Accent color"
}
