//
//  UpdateManager.swift
//  cuyor
//
//  Auto-update manager using Sparkle framework

import Foundation
import Sparkle

final class UpdateManager: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    private let appcastURLString = "https://raw.githubusercontent.com/cuyor/cuyor-client-mac/main/appcast.xml"
    private var updaterController: SPUStandardUpdaterController!

    override private init() {
        super.init()

        // Provide delegate-based feed URL so updates still work if generated Info.plist keys are stale.
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    /// Start automatic update checking
    /// Called once at app launch
    func start() {
        do {
            try updaterController.updater.start()
        } catch {
            NSLog("Failed to start Sparkle updater: \(error)")
        }
    }

    /// Manually trigger an update check with UI feedback
    /// Called when user clicks "Check for Updates…" menu item
    @objc func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Check for updates in the background without showing UI
    /// Called periodically or at app startup
    func checkForUpdatesInBackground() {
        updaterController.updater.checkForUpdatesInBackground()
    }

    // MARK: - SPUUpdaterDelegate

    func feedURLString(for updater: SPUUpdater) -> String? {
        appcastURLString
    }
}
