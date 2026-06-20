//
//  TSSettingsIndex.swift
//  TrollSpeed
//
//  Created by Lessica on 2024/1/25.
//

import Foundation

enum TSSettingsIndex: Int, CaseIterable {
    case displayMode = 0
    case passthroughMode
    case keepInPlace
    case hideAtSnapshot
    case usesRotation

    var key: String {
        switch self {
        case .displayMode:
            return HUDUserDefaultsKeyDisplayMode
        case .passthroughMode:
            return HUDUserDefaultsKeyPassthroughMode
        case .keepInPlace:
            return HUDUserDefaultsKeyKeepInPlace
        case .hideAtSnapshot:
            return HUDUserDefaultsKeyHideAtSnapshot
        case .usesRotation:
            return HUDUserDefaultsKeyUsesRotation
        }
    }

    var title: String {
        switch self {
        case .displayMode:
            return NSLocalizedString("ImGui Mode", comment: "TSSettingsIndex")
        case .passthroughMode:
            return NSLocalizedString("Pass-through", comment: "TSSettingsIndex")
        case .keepInPlace:
            return NSLocalizedString("Keep In-place", comment: "TSSettingsIndex")
        case .hideAtSnapshot:
            return NSLocalizedString("Hide @snapshot", comment: "TSSettingsIndex")
        case .usesRotation:
            return NSLocalizedString("Landscape", comment: "TSSettingsIndex")
        }
    }

    func subtitle(highlighted: Bool, restartRequired: Bool) -> String {
        switch self {
        case .displayMode:
            return highlighted
                ? NSLocalizedString("Demo Window", comment: "TSSettingsIndex")
                : NSLocalizedString("Main Window", comment: "TSSettingsIndex")
        case .passthroughMode:
            if restartRequired {
                return NSLocalizedString("Re-open to apply", comment: "TSSettingsIndex")
            } else {
                return highlighted ? NSLocalizedString("ON", comment: "TSSettingsIndex") : NSLocalizedString("OFF", comment: "TSSettingsIndex")
            }
        case .keepInPlace: fallthrough
        case .hideAtSnapshot:
            return highlighted ? NSLocalizedString("ON", comment: "TSSettingsIndex") : NSLocalizedString("OFF", comment: "TSSettingsIndex")
        case .usesRotation:
            return highlighted ? NSLocalizedString("Follow", comment: "TSSettingsIndex") : NSLocalizedString("Hide", comment: "TSSettingsIndex")
        }
    }
}
