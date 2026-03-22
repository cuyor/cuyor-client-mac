//
//  CoordinateTranslator.swift
//  cuyor
//
//  Created by Cuyor.
//


import AppKit

struct CoordinateTranslator {
    
    /// Translates local snippet coordinates to absolute macOS AppKit coordinates.
    static func getAbsoluteAppKitPoint(globalSnippetRect: NSRect, localX: Double, localY: Double, isRatio: Bool) -> NSPoint {
        
        let offsetX = isRatio ? (globalSnippetRect.width * CGFloat(localX)) : CGFloat(
            localX
        )
        let offsetY = isRatio ? (globalSnippetRect.height * CGFloat(localY)) : CGFloat(
            localY
        )
        
        let finalX = globalSnippetRect.minX + offsetX
        let finalY = globalSnippetRect.maxY - offsetY
        
        return NSPoint(x: finalX, y: finalY)
    }
}
