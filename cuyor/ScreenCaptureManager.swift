//
//  ScreenCaptureManager.swift
//  cuyor
//
//  Created by Cuyor.
//

import AppKit
import SwiftUI
import ScreenCaptureKit

// MARK: - ScreenCaptureManager

@MainActor
final class ScreenCaptureManager {

    static let shared = ScreenCaptureManager()

    private var overlayWindow: NSWindow?
    private var escapeMonitor: Any?

    private init() {}

    // MARK: - Public

    func startCapture(
        on screen: NSScreen?,
        excludingWindowNumber windowNumber: Int,
        completion: @escaping @MainActor (NSImage, CGRect) -> Void
    ) {
        guard overlayWindow == nil else { return }

        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens[0]

        // Build the transparent fullscreen overlay window
        let window = NSWindow(
            contentRect: targetScreen.frame,
            styleMask:   .borderless,
            backing:     .buffered,
            defer:       false
        )
        window.level            = NSWindow
            .Level(rawValue: Int(NSWindow.Level.popUpMenu.rawValue) + 1)
        window.backgroundColor  = .clear
        window.isOpaque         = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        let overlayView = ScreenCaptureOverlayView(
            onCapture: { [weak self] rect in
                guard let self else { return }
                self.dismissOverlay()
                Task { @MainActor in
                    await self.captureRegion(
                        rect,
                        screen: targetScreen,
                        excludingWindowNumber: windowNumber,
                        completion: completion
                    )
                }
            },
            onCancel: { [weak self] in
                self?.dismissOverlay()
            }
        )

        let hosting = NSHostingView(rootView: overlayView)
        hosting.frame = CGRect(origin: .zero, size: targetScreen.frame.size)
        window.contentView = hosting

        // ESC key handled here because SwiftUI onKeyPress needs focus state
        escapeMonitor = NSEvent
            .addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // kVK_Escape
                    self?.dismissOverlay()
                    return nil
                }
                return event
            }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        overlayWindow = window
    }

    // MARK: - Private

    private func dismissOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
        if let m = escapeMonitor {
            NSEvent.removeMonitor(m); escapeMonitor = nil
        }
    }

    private func captureRegion(
        _ rect: CGRect,
        screen: NSScreen,
        excludingWindowNumber windowNumber: Int,
        completion: @escaping @MainActor (NSImage, CGRect) -> Void
    ) async {
        do {
            let content   = try await SCShareableContent.current
            let displayID = screen.displayID

            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                return
            }

            let excludedApps = content.applications.filter {
                $0.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            let filter = SCContentFilter(
                display: display,
                excludingApplications: excludedApps,
                exceptingWindows: []
            )

            let config              = SCStreamConfiguration()
            
            config.sourceRect       = rect
            config.width            = Int(
                rect.width  * screen.backingScaleFactor
            )
            config.height           = Int(
                rect.height * screen.backingScaleFactor
            )

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let nsImage = NSImage(
                cgImage: cgImage,
                size: NSSize(width: rect.width, height: rect.height)
            )

            // CONVERSION: Map the local SwiftUI Top-Left rect
            let globalAppKitRect = NSRect(
                x: screen.frame.minX + rect.minX,
                y: screen.frame.maxY - rect.maxY,
                width: rect.width,
                height: rect.height
            )

            completion(nsImage, globalAppKitRect)
        } catch {
            print("[ScreenCaptureManager] capture error: \(error)")
        }
    }
}

// MARK: - NSScreen helper

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        (
            deviceDescription[NSDeviceDescriptionKey(
                "NSScreenNumber"
            )] as? CGDirectDisplayID
        ) ?? 0
    }
}
