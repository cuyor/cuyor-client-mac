//
//  WindowController.swift
//  cuyor
//
//  Created by Umar Ahmed on 11/03/2026.
//

import AppKit
import SwiftUI

// Borderless panel that can become key — required for TextField focus without .titled.
private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool  { true  }
    override var canBecomeMain: Bool { false }
    override var hasShadow: Bool { get { false } set {} }
}

final class WindowController {

    private var panel: NSPanel!
    private var positionTimer: Timer?
    private var hotKeyObserver: NSObjectProtocol?
    private var clickOutsideMonitor: Any?

    private let viewModel: CuyorViewModel

    init(viewModel: CuyorViewModel) {
        self.viewModel = viewModel
        setupPanel()
        startPositionTimer()
        setupHotKeyObserver()
        viewModel.onExpansionChanged = { [weak self] expanded in
            self?.applyExpansion(expanded)
        }
    }

    // MARK: - Panel

    private func setupPanel() {
        panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: Layout.windowCollapsed),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.level              = .floating
        panel.backgroundColor    = .clear
        panel.isOpaque           = false
        panel.hasShadow          = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Critical for glass effect: allows panel to composite against
        // content from other windows beneath it
        panel.animationBehavior        = .none
        panel.isMovableByWindowBackground = false

        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = .clear
            // Allow subpixel rendering against underlying window content
            contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        }

        let root = CuyorPromptView().environmentObject(viewModel)
        let hosting = NSHostingView(rootView: root)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        panel.contentView = hosting

        let mouse = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(
            x: mouse.x + Layout.windowOffsetX,
            y: mouse.y + Layout.windowOffsetY
        ))
        panel.orderFrontRegardless()
    }

    // MARK: - Mouse Tracking

    private func startPositionTimer() {
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updatePanelPosition()
        }
        RunLoop.main.add(t, forMode: .common)
        positionTimer = t
    }

    private func updatePanelPosition() {
        guard !viewModel.isExpanded else { return }
        let mouse = NSEvent.mouseLocation
        
        let offsetX = Layout.windowOffsetX
        let offsetY = Layout.windowOffsetY
        
        let target = NSPoint(
            x: mouse.x + offsetX,
            y: mouse.y + offsetY
        )

        let current = panel.frame.origin
        let factor: CGFloat = 0.18
        let smoothed = NSPoint(
            x: current.x + (target.x - current.x) * factor,
            y: current.y + (target.y - current.y) * factor
        )
        panel.setFrameOrigin(smoothed)
    }

    // MARK: - Hot Key

    private func setupHotKeyObserver() {
        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: .cuyorActivated,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            self?.viewModel.toggle()
        }
    }

    // MARK: - Expansion

    private func applyExpansion(_ expanded: Bool) {
        let collapsed = Layout.windowCollapsed
        let expanded_ = Layout.windowExpanded
        let targetSize = expanded ? expanded_ : collapsed

        if expanded {
            let frozenOrigin = NSPoint(
                x: panel.frame.minX,
                y: panel.frame.minY + (collapsed.height - expanded_.height) / 2
            )
            panel.setFrame(
                safeFrame(NSRect(origin: frozenOrigin, size: targetSize)),
                display: true, animate: false
            )
            // Activate app first, then make key — required for nonactivatingPanel
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            startClickOutsideMonitor()
        } else {
            let collapseOrigin = NSPoint(
                x: panel.frame.minX,
                y: panel.frame.midY - collapsed.height / 2
            )
            panel.setFrame(
                safeFrame(NSRect(origin: collapseOrigin, size: targetSize)),
                display: true, animate: false
            )
            stopClickOutsideMonitor()
            panel.resignKey()
            panel.orderFrontRegardless()
        }
    }

    // MARK: - Click-outside-to-dismiss

    private func startClickOutsideMonitor() {
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self else { return }
            if !self.panel.frame.contains(NSEvent.mouseLocation) {
                DispatchQueue.main.async { self.viewModel.collapse() }
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m); clickOutsideMonitor = nil }
    }

    // MARK: - Screen clamping

    private func safeFrame(_ frame: NSRect) -> NSRect {
        guard let screen = NSScreen.main?.visibleFrame else { return frame }
        let margin: CGFloat = 16
        var f = frame
        f.origin.x = max(screen.minX + margin, min(f.origin.x, screen.maxX - f.width  - margin))
        f.origin.y = max(screen.minY + margin, min(f.origin.y, screen.maxY - f.height - margin))
        return f
    }

    // MARK: - Cleanup

    deinit {
        positionTimer?.invalidate()
        if let o = hotKeyObserver      { NotificationCenter.default.removeObserver(o) }
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m) }
    }
}
