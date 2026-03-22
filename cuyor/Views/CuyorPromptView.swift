//
//  CuyorPromptView.swift
//  cuyor
//
//  Created by Cuyor.
//

import SwiftUI

struct CuyorPromptView: View {
    @EnvironmentObject private var vm: CuyorViewModel
    @FocusState private var focused: Bool
    
    private let capsuleW: CGFloat = CL.w - CL.pad * 2 - CL.iconSize - CL.gap
    private let r: CGFloat = 18

    private var iconRotation: Double {
        if vm.instructionMode, let target = vm.currentTargetPoint {
            let origin = vm.panelOrigin
            let dx = target.x - origin.x
            let dy = target.y - origin.y
            return (atan2(dy, dx) * 180 / .pi) - 90
        }
        return vm.isExpanded ? 0 : 90
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: CL.gap) {
                inputRow

                if vm.hasSecondaryContent {
                    responseSection
                        .transition(.opacity)
                }
                
                if vm.instructionMode && (vm.instructionPlan != nil) {
                    stepsSection
                }
            }
            .offset(x: CL.iconSize + CL.gap)
            .opacity(vm.isExpanded ? 1 : 0)
            .allowsHitTesting(vm.isExpanded)

            // Icon — always visible
            iconButton
        }
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
                vm.refreshDetectedApps()
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
            Image("cuyor.prompt.icon")
                .font(.system(size: 20))
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse, isActive: vm.isLoading || vm.isStreaming)
                .symbolEffect(.bounce, value: vm.isLoading || vm.isStreaming)
                .symbolEffect(.rotate, value: vm.isLoading || vm.isStreaming)
                .frame(width: CL.iconSize, height: CL.iconSize)
                .animation(
                    (vm.isLoading || vm.isStreaming)
                    ? .linear(duration: 2.0).repeatForever(autoreverses: false)
                    : .default,
                    value: vm.isLoading || vm.isStreaming
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
                    DispatchQueue.main.async {
                        vm.collapse()
                        vm.endInstructionMode()
                    }
                    return .handled
                }
                .onKeyPress(phases: .down) { press in
                    guard press.key == .return,
                          !press.modifiers
                        .contains(.shift) else { return .ignored }
                    DispatchQueue.main
                        .async {                
                            vm.beginInstructionMode()
                            vm.sendInstructionPlan()
                        }
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

            Menu {
                if vm.detectedApps.isEmpty {
                    Text("No apps detected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.detectedApps) { app in
                        Button {
                            vm.selectedApp = app
                        } label: {
                            HStack {
                                Text(app.name)
                                if vm.selectedApp?.id == app.id {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                Divider()
                Button {
                    vm.refreshDetectedApps()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 13))
                    .foregroundStyle(vm.selectedApp != nil
                                     ? AnyShapeStyle(.tint)
                                     : AnyShapeStyle(.secondary))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(vm.isStreaming)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 1)

            Button { 
                vm.collapse()
                vm.endInstructionMode()
                vm.capturedImage = nil
            } label: {
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

    private var stepsSection: some View {
        VStack(alignment: .center, spacing: 8) {
            
            VStack(alignment: .leading, spacing: 12) {
                if let plan = vm.instructionPlan,
                   let step = vm.currentInstructionStep {
                    
                    HStack(alignment: .top) {
                        Text(plan.goal)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(step.stepNumber)/\(plan.totalSteps)")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Text(step.instructionText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)

                    HStack(spacing: 6) {
                        Label(step.targetElement, systemImage: "scope")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                            .lineLimit(1)
                    }

                    if let value = step.inputValue, !value.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 10))
                            Text("Type:")
                                .font(.system(size: 11, weight: .medium))
                            Text(value)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.green.opacity(0.15)
                        )
                        .foregroundStyle(.green)
                        .cornerRadius(8)
                    }

                } else if vm.isLoading {
                    Text("Building guidance plan...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if let err = vm.instructionError {
                    Text(err)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                } else {
                    Text("No guidance steps available yet.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(
                maxWidth: capsuleW,
                alignment: .topLeading
            )
            .glassEffect(
                in: RoundedRectangle(cornerRadius: r, style: .continuous)
            )

            // --- Navigation Buttons ---
            HStack(alignment: .center, spacing: 8) {
                Button {
                    vm.previousInstructionStep()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Prev") // Shortened for smaller widths
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .glassEffect(in: UnevenRoundedRectangle(
                    topLeadingRadius: r,
                    bottomLeadingRadius: r,
                    bottomTrailingRadius: r/3,
                    topTrailingRadius: r/3,
                    style: .continuous
                ))
                .disabled(vm.currentInstructionIndex == 0)
                
                Button {
                    vm.nextInstructionStep()
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .glassEffect(in: UnevenRoundedRectangle(
                    topLeadingRadius: r/3,
                    bottomLeadingRadius: r/3,
                    bottomTrailingRadius: r,
                    topTrailingRadius: r,
                    style: .continuous
                ))
                .disabled(
                    vm.currentInstructionIndex >= (
                        vm.instructionPlan?.steps.count ?? 0
                    ) - 1
                )
            }
            .frame(maxWidth: capsuleW)
        }
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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: capsuleW, alignment: .topLeading)
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
