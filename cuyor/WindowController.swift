//
//  WindowController.swift
//  cuyor
//
//  Created by Cuyor.
//

import AppKit
import SwiftUI

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool  { true  }
    override var canBecomeMain: Bool { false }
    override var hasShadow: Bool { get { false } set {} }
}

final class WindowController {

    private var panel: NSPanel!
    private var positionTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var clickOutsideMonitor: Any?
    private let vm: CuyorViewModel

    init(viewModel: CuyorViewModel) {
        vm = viewModel
        buildPanel()
        startMouseTracking()
        listenForHotKeys()
        vm.onExpansionChanged = { [weak self] in self?.applyExpansion($0) }
        vm.onCaptureRequested = { [weak self] in self?.triggerCapture() }
        vm.requestPanelOrigin = { [weak self] in
            guard let self else { return .zero }
            let frame = self.panel.frame
            return CGPoint(x: frame.midX, y: frame.midY)
        }
    }

    // MARK: - Panel

    private func buildPanel() {
        let p = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: CL.collapsed),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        p.level              = .floating
        p.backgroundColor    = .clear
        p.isOpaque           = false
        p.hasShadow          = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.animationBehavior  = .none
        p.isMovableByWindowBackground = false

        let hosting = NSHostingView(
            rootView: CuyorPromptView().environmentObject(vm)
        )
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        p.contentView = hosting

        p
            .setFrameOrigin(
                panelOrigin(cursor: NSEvent.mouseLocation, size: CL.collapsed)
            )
        p.orderFrontRegardless()
        panel = p
    }

    // MARK: - Mouse tracking

    private func startMouseTracking() {
        let t = Timer(timeInterval: 1 / 60.0, repeats: true) { [weak self] _ in
            guard let self, !self.vm.isExpanded else { return }
            let target = self.panelOrigin(
                cursor: NSEvent.mouseLocation,
                size: CL.collapsed
            )
            let cur    = self.panel.frame.origin
            let s: CGFloat = 0.18
            self.panel.setFrameOrigin(NSPoint(
                x: cur.x + (target.x - cur.x) * s,
                y: cur.y + (target.y - cur.y) * s
            ))
        }
        RunLoop.main.add(t, forMode: .common)
        positionTimer = t
    }

    // MARK: - Hotkeys

    private func listenForHotKeys() {
        let nc = NotificationCenter.default
        observers
            .append(
                nc
                    .addObserver(forName: .cuyorActivated, object: nil, queue: .main) { [weak self] _ in self?.vm.toggle()
                    })
        observers
            .append(
                nc
                    .addObserver(forName: .cuyorCaptureActivated, object: nil, queue: .main) { [weak self] _ in self?.triggerCapture()
                    })
    }

    // MARK: - Screen capture

    private func triggerCapture() {
        ScreenCaptureManager.shared.startCapture(
            on: panel.screen ?? NSScreen.main,
            excludingWindowNumber: panel.windowNumber
        ) { [weak self] capturedImage, snippetRect in
            guard let self else { return }
            self.vm.capturedImage = capturedImage
            self.vm.savedSnippetRect = snippetRect
            if !self.vm.isExpanded { self.vm.toggle() }
        }
    }

    // MARK: - Expansion

    private func applyExpansion(_ expanded: Bool) {
        let size = expanded ? CL.expanded : CL.collapsed
        // Pin the top edge so the icon doesn't jump when the panel grows downward.
        let origin = NSPoint(
            x: panel.frame.minX,
            y: panel.frame.maxY - size.height
        )
        panel
            .setFrame(
                clamp(NSRect(origin: origin, size: size)),
                display: true,
                animate: false
            )

        if expanded {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            clickOutsideMonitor = NSEvent
                .addGlobalMonitorForEvents(
                    matching: [.leftMouseDown, .rightMouseDown]
                ) {
                    [weak self] _ in
                    guard let self, !self.panel.frame
                        .contains(NSEvent.mouseLocation) else { return }
                    DispatchQueue.main.async { self.vm.collapse() }
                }
        } else {
            if let m = clickOutsideMonitor {
                NSEvent.removeMonitor(m); clickOutsideMonitor = nil
            }
            panel.resignKey()
            panel.orderFrontRegardless()
        }
    }

    // MARK: - Helpers

    /// Origin so that the *icon's top-left corner* sits dx right and dy below
    /// the cursor tip. Accounts for the CL.pad inset between panel edge and icon.
    private func panelOrigin(cursor: NSPoint, size: CGSize) -> NSPoint {
        NSPoint(
            x: cursor.x + CL.dx - CL.pad,
            y: cursor.y - CL.dy + CL.pad - size.height
        )
    }

    /// Keeps the panel inside the main screen's visible area.
    private func clamp(_ frame: NSRect) -> NSRect {
        let targetScreen = NSScreen.screens.first { $0.frame.intersects(frame) } 
        ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        ?? NSScreen.screens.first
        
        guard let vis = targetScreen?.visibleFrame else { return frame }
        
        let m: CGFloat = 16
        var f = frame
        
        f.origin.x = max(vis.minX + m, min(f.origin.x, vis.maxX - f.width  - m))
        
        f.origin.y = max(vis.minY + m, min(f.origin.y, vis.maxY - f.height - m))
        
        return f
    }

    deinit {
        positionTimer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m) }
    }
}
