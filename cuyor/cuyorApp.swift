//
//  cuyorApp.swift
//  cuyor
//
//  Created by Umar Ahmed on 10/03/2026.
//

import SwiftUI
import AppKit

@main
struct CuyorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The floating panel is managed by WindowController;
        // suppress the default SwiftUI window entirely.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: WindowController?
    private let viewModel = CuyorViewModel()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Must be set before anything else so the app never becomes "active"
        // and global event monitors fire immediately.
        NSApp.setActivationPolicy(.accessory)
        // Resign immediately in case Xcode/launch briefly made us active.
        NSApp.deactivate()
        windowController = WindowController(viewModel: viewModel)
        HotKeyManager.shared.register()
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system
            .statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // 1. Create a configuration (e.g., 18pt weight bold)
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            
            // 2. Apply it to your custom icon
            button.image = NSImage(named: "cuyor.menu.icon")?.withSymbolConfiguration(config)
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

        let prefsItem = NSMenuItem(
            title: "Preferences…",
            action: nil,
            keyEquivalent: ","
        )
        prefsItem.isEnabled = false
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        menu
            .addItem(
                NSMenuItem(
                    title: "Quit Cuyor",
                    action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q"
                )
            )

        statusItem?.menu = menu
    }

    @objc private func toggleBubble() {
        viewModel.toggle()
    }
}
