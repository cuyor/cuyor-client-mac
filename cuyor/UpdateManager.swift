//
//  UpdateManager.swift
//  cuyor
//
//  Auto-update manager using Sparkle framework

import Foundation
import Sparkle

final class UpdateManager: NSObject {
    static let shared = UpdateManager()

    private let updaterController: SPUStandardUpdaterController

    override private init() {
        // Use Sparkle's standard controller for a menu-bar app integration.
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        super.init()
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
}
