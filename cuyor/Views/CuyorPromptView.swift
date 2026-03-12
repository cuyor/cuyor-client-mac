//
//  CuyorPromptView.swift
//  cuyor
//
//  Created by Umar Ahmed on 11/03/2026.
//

import SwiftUI

struct CuyorPromptView: View {
    @EnvironmentObject private var viewModel: CuyorViewModel
    @FocusState private var textFieldFocused: Bool
    
    let cornerRadius: CGFloat = 18
    
    var body: some View {
        ZStack(alignment: .topLeading){
            
            
            VStack {
                HStack(spacing: Layout.spacing) {
                    TextField(
                        "Ask Cuyor...",
                        text: $viewModel.inputText,
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .font(.system(size: 13))
                    .focused($textFieldFocused)
                    .onKeyPress(.escape) {
                        viewModel.collapse()
                        return .handled
                    }
                    .opacity(viewModel.isExpanded ? 1.0 : 0)

                    Button {
                        viewModel.collapse()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .opacity(viewModel.isExpanded ? 1.0 : 0)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: Layout.capsuleContentWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                )
                .glassEffect(
                    in: RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                )
                .opacity(viewModel.isExpanded ? 1 : 0)
                .offset(
                    x: viewModel.isExpanded ? Layout.iconSize + Layout.spacing : 0
                )
                .allowsHitTesting(viewModel.isExpanded)
                
                VStack(spacing: Layout.spacing) {
                    Text("Analysing...")
                    
                    AsyncImage(
                        url: URL(
                            string: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1064&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
                        )
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        // Shows while the image is loading
                        ProgressView()
                    }
                    .frame(width: .infinity)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: cornerRadius/2,
                            style: .continuous
                        )
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: Layout.capsuleContentWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                )
                .glassEffect(
                    in: RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                )
                .opacity(viewModel.isExpanded ? 1 : 0)
                .offset(
                    x: viewModel.isExpanded ? Layout.iconSize + Layout.spacing : 0
                )
                .allowsHitTesting(viewModel.isExpanded)
            }
            
            
            Button {
                viewModel.toggle()
            } label: {
                Image("cuyor-prompt-icon")
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
            }
            .buttonStyle(.plain)
            .glassEffect(in: Circle())
    
        }
        .frame(width: 340, height: 60, alignment: .topLeading)
        .padding(.horizontal, Layout.glowH)
        .padding(.vertical, Layout.glowV)
        .animation(
            .spring(response: 0.32, dampingFraction: 0.84),
            value: viewModel.isExpanded
        )
        .onChange(of: viewModel.isExpanded) { _, isExpanded in
            if isExpanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textFieldFocused = true
                }
            } else {
                textFieldFocused = false
            }
        }
    }
}

#Preview {
    CuyorPromptView()
        .environmentObject(CuyorViewModel())
        .frame(width: 500, height: 500)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .padding(.all)
        )
}
