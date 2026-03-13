//
//  CuyorPromptView.swift
//  cuyor
//
//  Created by Umar Ahmed on 11/03/2026.
//

import SwiftUI

struct CuyorPromptView: View {
    @EnvironmentObject private var vm: CuyorViewModel
    @FocusState private var focused: Bool

    // Capsule width fits between the icon and the right padding edge.
    private let capsuleW: CGFloat = CL.w - CL.pad * 2 - CL.iconSize - CL.gap
    private let r: CGFloat = 18

    var body: some View {
        ZStack(alignment: .topLeading) {

            // Right-side content now lays out vertically, so response follows
            // the real input height as the text field grows.
            VStack(alignment: .leading, spacing: CL.gap) {
                inputRow

                if vm.hasSecondaryContent {
                    responseSection
                        .transition(.opacity)
                }
            }
            .offset(x: CL.iconSize + CL.gap)
            .opacity(vm.isExpanded ? 1 : 0)
            .allowsHitTesting(vm.isExpanded)

            // Icon — always visible
            iconButton
        }
        // Fill the full padded area so offset children aren't clipped.
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .padding(CL.pad)
        .padding(.trailing, 0)
        .animation(
            .spring(response: 0.32, dampingFraction: 0.84),
            value: vm.isExpanded
        )
        .animation(.default, value: vm.hasSecondaryContent)
        .onChange(of: vm.isExpanded) { _, expanded in
            if expanded {
                DispatchQueue.main
                    .asyncAfter(deadline: .now() + 0.1) { focused = true }
            } else {
                focused = false
            }
        }
    }

    // MARK: - Icon

    private var iconButton: some View {
        Button { vm.toggle() } label: {
            Image(
                systemName: vm.instructionMode ? "arrow.up.circle.dotted" : "sparkle"
            )
            .font(.system(size: 20))
            .symbolRenderingMode(.hierarchical)
            .frame(width: CL.iconSize, height: CL.iconSize, alignment: .center)
            .contentTransition(.symbolEffect(.replace))
            .rotationEffect(.degrees(vm.isExpanded ? 0 : 90.0))
            .animation(
                .bouncy(
                    duration: 0.3,
                    extraBounce: 0.2
                ),
                value: vm.isExpanded
            )
        }
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
    }

    // MARK: - Input row

    private var inputRow: some View {
        HStack(spacing: 6) {
            TextField("Ask Cuyor...", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .font(.system(size: 13))
                .focused($focused)
                .disabled(vm.isStreaming)
                .onKeyPress(.escape) {
                    DispatchQueue.main.async { vm.collapse() }
                    return .handled
                }
                .onKeyPress(phases: .down) { press in
                    guard press.key == .return,
                          !press.modifiers
                        .contains(.shift) else { return .ignored }
                    DispatchQueue.main.async { vm.sendQuery() }
                    return .handled
                }

            Button { vm.startCapture() } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 13))
                    .foregroundStyle(vm.capturedImage != nil
                                     ? AnyShapeStyle(.tint)
                                     : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .disabled(vm.isStreaming)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 1)

            Button { vm.collapse() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: capsuleW, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(in: RoundedRectangle(cornerRadius: r, style: .continuous))
    }

    // MARK: - Response section

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 6) {

            // Attached screenshot thumbnail
            if let img = vm.capturedImage {
                HStack(spacing: 6) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text("Screenshot attached")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button { vm.clearCapture() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Response body
            if vm.isLoading && vm.responseText.isEmpty {
                HStack(spacing: 6) {
                    Text("Thinking...")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .foregroundStyle(.gray.opacity(0.3))
                        .overlay {
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.8), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .offset(x: vm.isLoading ? 200 : -200)
                            .mask(
                                Text("Shimmering Text").font(.largeTitle.bold())
                            )
                        }
                }
            } else if !vm.responseText.isEmpty {
                ScrollView {
                    Text(vm.responseText)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .animation(.default, value: vm.responseText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: capsuleW, height: CL.responseH, alignment: .topLeading)
        .glassEffect(in: RoundedRectangle(cornerRadius: r, style: .continuous))
    }
}

#Preview {
    CuyorPromptView()
        .environmentObject(CuyorViewModel())
        .frame(width: CL.expanded.width, height: CL.expanded.height)
        .background(
            LinearGradient(colors: [.blue, .purple],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
}
