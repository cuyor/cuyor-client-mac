//
//  GhostCursorView.swift
//  cuyor
//
//  Created by Cuyor.
//

import SwiftUI

// MARK: - Ghost Cursor View
struct GhostCursorView: View {
    var actionLabel: String? = nil
    private let r: CGFloat = 18
    @State private var isVisible = false
    
    let colors: [Color] = [.red, .blue, .green, .yellow, .purple]
    @State private var selectedColor: Color = .blue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "pointer.arrow.ipad")
                .font(.system(size: 20))
                .foregroundStyle(selectedColor)
                .offset(x: -4, y: -4)
            
            if let actionLabel {
                Text(actionLabel)
                    .padding(.all, 8)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: r/3,
                            bottomLeadingRadius: r,
                            bottomTrailingRadius: r,
                            topTrailingRadius: r,
                            style: .continuous
                        )
                        .fill(selectedColor)
                        .shadow(
                            color: selectedColor.opacity(0.3),
                            radius: 5,
                            x: 0,
                            y: 3
                        )
                    )
            }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.5, anchor: .topLeading) 
        .onAppear {
            selectedColor = colors.randomElement() ?? .blue
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isVisible = true
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }
}


// MARK: - Preview
#Preview {
    GhostCursorView(
        actionLabel: "Type \"Google\" in the search field"
    )
    .padding(32)
    .background(
        LinearGradient(colors: [.blue, .purple],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    )
}
