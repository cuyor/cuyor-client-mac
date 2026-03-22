//
//  cuyorApp.swift
//  cuyor
//
//  Created by Cuyor.
//

import SwiftUI
import AppKit

@main
struct CuyorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController:  WindowController?
    private var settingsWindow:    NSWindow?
    private let viewModel = CuyorViewModel()
    private let settingsViewModel = SettingsViewModel()
    private var statusItem: NSStatusItem?
    private let updateManager = UpdateManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.deactivate()

        // Initialize auto-update framework
        updateManager.start()
        updateManager.checkForUpdatesInBackground()

        windowController = WindowController(viewModel: viewModel)
        HotKeyManager.shared.register()
        setupMenuBar()
        Task { await settingsViewModel.validateStoredLicenseOnLaunch() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system
            .statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(
                pointSize: 18,
                weight: .regular
            )
            button.image = NSImage(named: "cuyor.prompt.icon")?
                .withSymbolConfiguration(config)
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Show / Hide",
            action: #selector(toggleBubble),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let checkUpdatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        checkUpdatesItem.target = self
        menu.addItem(checkUpdatesItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Cuyor",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleBubble() {
        viewModel.toggle()
    }

    @objc private func checkForUpdates() {
        updateManager.checkForUpdates()
    }

    @objc private func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 420),
            styleMask:   [.titled, .closable, .miniaturizable],
            backing:     .buffered,
            defer:       false
        )
        window.title           = "Cuyor Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView     = NSHostingView(
            rootView: SettingsView(viewModel: settingsViewModel)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }
}
