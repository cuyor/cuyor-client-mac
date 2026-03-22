//
//  CuyorViewModel.swift
//  cuyor
//
//  Created by Cuyor.
//

import SwiftUI
import Combine
import CoreGraphics

struct CuyorInstructionStep: Codable, Identifiable, Equatable {
    let stepNumber: Int
    let actionType: String
    let targetElement: String
    let instructionText: String
    let x: CGFloat
    let y: CGFloat
    let inputValue: String?
    var id: Int { stepNumber }
    var point: CGPoint { CGPoint(x: x, y: y) }
}

struct CuyorInstructionPlan: Codable, Equatable {
    let goal: String
    let totalSteps: Int
    let steps: [CuyorInstructionStep]
    let confidence: Double
    let fallbackText: String?
}

struct DetectedApp: Identifiable, Equatable {
    let id: String
    let name: String
    var bundleID: String { id }
}

// MARK: - Layout
enum CL {
    static let iconSize:  CGFloat = 32
    static let pad:       CGFloat = 16
    static let gap:       CGFloat = 8
    static let inputH:    CGFloat = 44
    static let responseH: CGFloat = 250
    static let w: CGFloat = 300

    static let windowBufferWidthGap: CGFloat  = 24
    static let windowBufferHeightGap: CGFloat = 48

    static let collapsed = CGSize(
        width:  w + windowBufferWidthGap,
        height: (inputH + responseH + gap + pad * 2) + windowBufferHeightGap
    )
    static let expanded = CGSize(
        width:  w + windowBufferWidthGap,
        height: (inputH + responseH + gap + pad * 2) + windowBufferHeightGap
    )

    static let dx: CGFloat = 24
    static let dy: CGFloat = -15
}

// MARK: - ViewModel

final class CuyorViewModel: ObservableObject {

    @Published var isExpanded:           Bool    = false
    @Published var instructionMode:      Bool    = false
    @Published var inputText:            String  = ""
    @Published var capturedImage:        NSImage? = nil
    @Published var responseText:         String  = ""
    @Published var isLoading:            Bool    = false
    @Published var isStreaming:          Bool    = false
    @Published var instructionPlan:      CuyorInstructionPlan?
    @Published var savedSnippetRect:     CGRect  = .zero
    @Published var currentInstructionIndex: Int  = 0
    @Published var instructionError:     String?
    @Published var detectedApps:         [DetectedApp] = []
    @Published var selectedApp:          DetectedApp?

    private var ghostCursorWindow: NSWindow?

    var hasSecondaryContent: Bool {
        capturedImage != nil || isLoading || !responseText.isEmpty
    }

    var onExpansionChanged:   ((Bool) -> Void)?
    var onCaptureRequested:   (() -> Void)?
    var requestPanelOrigin:   (() -> CGPoint)?

    // MARK: - General UI

    func toggle() {
        isExpanded.toggle()
        onExpansionChanged?(isExpanded)
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        onExpansionChanged?(false)
    }

    func startCapture() { onCaptureRequested?() }
    func clearCapture()  { capturedImage = nil   }

    // MARK: - App detection

    func refreshDetectedApps() {
        let apps = AccessibilityTreeManager.shared.listDetectedApps()
            .map { DetectedApp(id: $0.bundleID, name: $0.name) }
        detectedApps = apps
        if let sel = selectedApp, !apps.contains(where: { $0.id == sel.id }) {
            selectedApp = apps.first
        } else if selectedApp == nil {
            selectedApp = apps.first
        }
    }

    // MARK: - Instruction mode

    func beginInstructionMode() {
        instructionMode = true
        instructionError = nil
    }

    func endInstructionMode() {
        instructionMode = false
        instructionPlan = nil
        currentInstructionIndex = 0
        instructionError = nil
        hideGhostCursor()
    }

    var currentInstructionStep: CuyorInstructionStep? {
        guard let plan = instructionPlan,
              !plan.steps.isEmpty,
              plan.steps.indices.contains(currentInstructionIndex)
        else { return nil }
        return plan.steps[currentInstructionIndex]
    }

    var currentTargetPoint: CGPoint? {
        currentInstructionStep?.point
    }

    var panelOrigin: CGPoint {
        requestPanelOrigin?() ?? .zero
    }

    func nextInstructionStep() {
        guard let plan = instructionPlan else { return }
        currentInstructionIndex = min(
            currentInstructionIndex + 1,
            plan.steps.count - 1
        )
        updateGhostCursorForCurrentStep()
    }

    func previousInstructionStep() {
        currentInstructionIndex = max(currentInstructionIndex - 1, 0)
        updateGhostCursorForCurrentStep()
    }

    // MARK: - Ghost cursor

    private func updateGhostCursorForCurrentStep() {
        guard let step = currentInstructionStep else {
            hideGhostCursor()
            return
        }
        let absolutePoint = CoordinateTranslator.getAbsoluteAppKitPoint(
            globalSnippetRect: savedSnippetRect,
            localX: Double(step.x),
            localY: Double(step.y),
            isRatio: true
        )
        showGhostCursor(at: absolutePoint, actionLabel: step.actionType)
    }

    private func showGhostCursor(at point: CGPoint, actionLabel: String) {
        let windowSize   = CGSize(width: 280, height: 90)
        let windowOrigin = CGPoint(x: point.x, y: point.y - windowSize.height)

        let window: NSWindow
        if let existing = ghostCursorWindow {
            window = existing
            window
                .setFrame(
                    NSRect(origin: windowOrigin, size: windowSize),
                    display: true
                )
        } else {
            window = NSWindow(
                contentRect: NSRect(origin: windowOrigin, size: windowSize),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level                = .floating
            window.backgroundColor      = .clear
            window.isOpaque             = false
            window.hasShadow            = false
            window.ignoresMouseEvents   = true
            window.collectionBehavior   = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary
            ]
            ghostCursorWindow           = window
        }

        window.contentView = NSHostingView(
            rootView: GhostCursorView(actionLabel: actionLabel)
        )
        window.orderFrontRegardless()
    }

    private func hideGhostCursor() {
        ghostCursorWindow?.orderOut(nil)
    }

    // MARK: - Main request

    func sendInstructionPlan() {
        let q = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty || capturedImage != nil, !isStreaming else { return }

        guard AccessibilityTreeManager.shared
            .isPermissionGranted(prompt: true) else {
            instructionError = "Enable Accessibility access for Cuyor in System Settings, then try again."
            responseText     = instructionError ?? ""
            return
        }

        responseText     = ""
        instructionError = nil
        isLoading        = true
        isStreaming       = true

        let img    = capturedImage
        let region = savedSnippetRect

        Task { @MainActor in
            do {
                let axTree = await AccessibilityTreeManager.shared.captureTreeJSON(
                    bundleID: selectedApp?.bundleID
                )

                let plan = try await CuyorAPIClient.shared.chatPlan(
                    query: q,
                    image: img,
                    accessibilityTree: axTree,
                    captureRegion: region
                )

                instructionPlan         = plan
                currentInstructionIndex = 0
                instructionMode         = !plan.steps.isEmpty
                isLoading               = false
                isStreaming             = false

                updateGhostCursorForCurrentStep()

            } catch {
                instructionError = "Couldn't build guidance plan from backend."
                responseText     = instructionError ?? ""
                isLoading        = false
                isStreaming      = false
            }
        }
    }

    // MARK: - Reset

    private func reset() {
        instructionMode         = false
        inputText               = ""
        capturedImage           = nil
        responseText            = ""
        isLoading               = false
        isStreaming             = false
        instructionPlan         = nil
        currentInstructionIndex = 0
        instructionError        = nil
        hideGhostCursor()
    }
}
