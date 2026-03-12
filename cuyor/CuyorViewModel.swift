//
//  CuyorViewModel.swift
//  cuyor
//
//  Created by Umar Ahmed on 11/03/2026.
//

import SwiftUI
import Combine

// MARK: - Layout

enum Layout {
    // MARK: Primitives — the only values you ever need to change
    static let iconSize: CGFloat     = 32   // icon circle diameter
    static let spacing: CGFloat      = 8    // gap between icon and capsule
    static let capsuleWidth: CGFloat = 260  // expanded input pill width

    /// The SwiftUI content frame used by the prompt view (matches its .frame modifier).
    static let contentWidth: CGFloat  = 280
    static let contentHeight: CGFloat = 60

    /// Glow bleed — prevents glassEffect shadow from being clipped by the window edge.
    static let glowH: CGFloat = 24   // horizontal (left + right)
    static let glowV: CGFloat = 32   // vertical   (top  + bottom)

    /// Where the icon sits relative to the cursor tip — adjust to taste.
    static let cursorOffsetX: CGFloat = 28   // icon left edge, rightward from cursor
    static let cursorOffsetY: CGFloat = 10   // icon center, below cursor

    // MARK: Derived — auto-calculated from the primitives above

    /// Width of the input capsule — fills the remaining space after the icon.
    static let capsuleContentWidth: CGFloat = contentWidth - iconSize - spacing

    /// NSWindow sizes — include glow bleed on every side.
    /// Height is the same for both states so the window never resizes vertically,
    /// preventing the icon from jumping when the panel expands.
    static let windowCollapsed = CGSize(
        width:  iconSize      + glowH * 2,   // just the icon + horizontal glow
        height: contentHeight + glowV * 2    // full content height always
    )
    static let windowExpanded = CGSize(
        width:  contentWidth  + glowH * 2,   // full content + horizontal glow
        height: contentHeight + glowV * 2    // same height as collapsed
    )

    /// NSWindow origin offset from the mouse cursor.
    /// windowOffsetY accounts for contentHeight so the icon (top-aligned in the view)
    /// stays at cursorOffsetY below the cursor tip.
    static let windowOffsetX: CGFloat =  cursorOffsetX - glowH
    static let windowOffsetY: CGFloat = -(cursorOffsetY + contentHeight + glowV - iconSize / 2)
}

final class CuyorViewModel: ObservableObject {

    @Published var isExpanded: Bool = false
    @Published var inputText: String = ""

    /// WindowController observes this to sync NSPanel size/state.
    var onExpansionChanged: ((Bool) -> Void)?

    func toggle() {
        isExpanded.toggle()
        if !isExpanded { inputText = "" }
        onExpansionChanged?(isExpanded)
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        inputText = ""
        onExpansionChanged?(false)
    }
}
