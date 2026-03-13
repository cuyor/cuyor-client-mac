//
//  ScreenCaptureOverlayView.swift
//  cuyor
//
//  Created by Umar Ahmed on 12/03/2026.
//

import SwiftUI

// MARK: - Even-odd mask that punches a transparent hole for the selection

private struct SelectionMaskShape: Shape {
    let selection: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)          // fill entire bounds …
        path
            .addRect(
                selection
            )     // … then cut the selection out (even-odd rule)
        return path
    }
}

// MARK: - Overlay view

struct ScreenCaptureOverlayView: View {
    /// Called with the selected rect in the view's local coordinate space when the
    /// drag finishes with a valid selection (width > 10, height > 10).
    let onCapture: (CGRect) -> Void
    /// Called when the user cancels (too-small drag, or ESC via the window-level
    /// keyDown monitor installed by ScreenCaptureManager).
    let onCancel: () -> Void

    @State private var startPoint:  CGPoint = .zero
    @State private var currentPoint: CGPoint = .zero
    @State private var isDragging:  Bool = false

    private var selectionRect: CGRect {
        CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width:  abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isDragging && selectionRect.width > 2 && selectionRect.height > 2 {
                    // Dimmed area with a transparent hole cut through it
                    SelectionMaskShape(selection: selectionRect)
                        .fill(
                            Color.black.opacity(0.45),
                            style: FillStyle(eoFill: true)
                        )

                    // Border around the selection
                    Rectangle()
                        .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                        .frame(
                            width: selectionRect.width,
                            height: selectionRect.height
                        )
                        .position(x: selectionRect.midX, y: selectionRect.midY)

                    // Size label above the selection
                    Text(
                        "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
                    )
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())
                    .position(
                        x: selectionRect.midX,
                        y: max(selectionRect.minY - 18, 14)
                    )
                } else {
                    // Idle state: full-screen dim + instructions
                    Color.black.opacity(0.45)

                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("Drag to select an area")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("ESC to cancel")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if !isDragging {
                            startPoint = value.startLocation
                        }
                        isDragging    = true
                        currentPoint  = value.location
                    }
                    .onEnded { _ in
                        isDragging = false
                        let rect = selectionRect
                        if rect.width > 10 && rect.height > 10 {
                            onCapture(rect)
                        } else {
                            onCancel()
                        }
                    }
            )
            .onHover { inside in
                if inside {
                    NSCursor.crosshair.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .ignoresSafeArea()
    }
}
