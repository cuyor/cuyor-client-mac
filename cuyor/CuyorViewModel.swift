//
//  CuyorViewModel.swift
//  cuyor
//
//  Created by Umar Ahmed on 11/03/2026.
//

import SwiftUI
import Combine

// MARK: - Layout
// These are the ONLY values that drive the whole UI. Change them here; nothing
// else needs updating.
enum CL {
    static let iconSize:  CGFloat = 32
    static let pad:       CGFloat = 16   // inset between panel edge and content
    static let gap:       CGFloat = 8    // icon → input capsule gap
    static let inputH:    CGFloat = 44   // input row height
    static let responseH: CGFloat = 150  // response panel height

    // ── Root size knob ────────────────────────────────────────────────────────
    static let w: CGFloat = 300          // ← change this to resize the panel
    // expanded height is fully derived; nothing else to touch.

    static let windowBufferWidthGap: CGFloat = 24
    static let windowBufferHeightGap: CGFloat = 48

    // NSPanel frame sizes — source of truth for WindowController.
    static let collapsed = CGSize(width: 80, height: 80)
    static let expanded  = CGSize(
        width:  w + windowBufferWidthGap,
        height: (inputH + responseH + gap + pad * 2) + windowBufferHeightGap
    )

    // Visual offset from cursor tip to the icon's top-left corner.
    // dx > 0 → icon is to the right of the cursor
    // dy > 0 → icon is below the cursor
    static let dx: CGFloat = 24
    static let dy: CGFloat = -15
}

// MARK: - ViewModel

final class CuyorViewModel: ObservableObject {

    @Published var isExpanded:    Bool     = false
    @Published var instructionMode:    Bool     = false
    @Published var inputText:     String   = ""
    @Published var capturedImage: NSImage? = nil
    @Published var responseText:  String   = ""
    @Published var isLoading:     Bool     = false
    @Published var isStreaming:   Bool     = false

    /// True whenever the response panel should be visible.
    var hasSecondaryContent: Bool {
        capturedImage != nil || isLoading || !responseText.isEmpty
    }

    // Callbacks set by WindowController.
    var onExpansionChanged: ((Bool) -> Void)?
    var onCaptureRequested: (() -> Void)?

    func toggle() {
        isExpanded.toggle()
        if !isExpanded { reset() }
        onExpansionChanged?(isExpanded)
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        reset()
        onExpansionChanged?(false)
    }

    func startCapture() { onCaptureRequested?() }
    func clearCapture()  { capturedImage = nil    }

    func sendQuery() {
        let q = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty || capturedImage != nil, !isStreaming else { return }
        responseText = ""
        isLoading    = true
        let img = capturedImage
        Task { @MainActor in
            isStreaming = true
            do {
                for try await token in CuyorAPIClient.shared
                    .chat(query: q, image: img) {
                    responseText += token
                    isLoading = false
                }
            } catch {
                responseText = "Couldn't reach backend at localhost:8000."
                isLoading = false
            }
            isStreaming = false
        }
    }

    private func reset() {
        inputText = ""; capturedImage = nil
        responseText = ""; isLoading = false; isStreaming = false
    }
}
