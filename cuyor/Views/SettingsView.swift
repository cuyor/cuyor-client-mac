//
//  SettingsView.swift
//  cuyor
//
//  Created by Cuyor.
//

import SwiftUI

// MARK: - Settings sections

private enum SettingsTab: String, CaseIterable {
    case account = "Account"
    case backend = "Backend"
    case about   = "About"

    var icon: String {
        switch self {
        case .account: return "person.crop.circle"
        case .backend: return "server.rack"
        case .about:   return "info.circle"
        }
    }
}

// MARK: - Main settings view

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            AccountSettingsView(viewModel: viewModel)
                .tabItem {
                    Label(
                        SettingsTab.account.rawValue,
                        systemImage: SettingsTab.account.icon
                    )
                }
            
            BackendSettingsView(viewModel: viewModel)
                .tabItem {
                    Label(
                        SettingsTab.backend.rawValue,
                        systemImage: SettingsTab.backend.icon
                    )
                }
            
            AboutSettingsView()
                .tabItem {
                    Label(
                        SettingsTab.about.rawValue,
                        systemImage: SettingsTab.about.icon
                    )
                }
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - Account / License

private struct AccountSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("License") {
                if viewModel.isActivated {
                    LabeledContent("Email", value: viewModel.userEmail)
                    LabeledContent("Plan")  {
                        PlanBadge(plan: viewModel.licensePlan)
                    }
                    LabeledContent("Device") {
                        Text(viewModel.deviceFingerprint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    HStack {
                        Spacer()
                        Button("Deactivate", role: .destructive) {
                            viewModel.deactivateLicense()
                        }
                    }
                } else {
                    Text("No license activated on this device.")
                        .foregroundStyle(.secondary)
                }
            }

            if !viewModel.isActivated {
                Section("Activate License") {
                    SecureField(
                        "License key (cuyor_...)",
                        text: $viewModel.licenseKeyInput
                    )
                    .textContentType(.password)

                    if !viewModel.statusMessage.isEmpty {
                        Label(
                            viewModel.statusMessage,
                            systemImage: viewModel.statusIsError ? "xmark.circle" : "checkmark.circle"
                        )
                        .foregroundStyle(
                            viewModel.statusIsError ? .red : .green
                        )
                        .font(.caption)
                    }

                    HStack {
                        Spacer()
                        Button(
                            viewModel.isActivating ? "Activating..." : "Activate"
                        ) {
                            Task { await viewModel.activateLicense() }
                        }
                        .disabled(
                            viewModel.licenseKeyInput
                                .trimmingCharacters(
                                    in: .whitespaces
                                ).isEmpty || viewModel.isActivating
                        )
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Plan badge

private struct PlanBadge: View {
    let plan: String

    private var color: Color {
        switch plan.lowercased() {
        case "max":      return .purple
        case "standard": return .blue
        default:         return .secondary
        }
    }

    var body: some View {
        Text(plan.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Backend settings

private struct BackendSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedModelOption: String = "gemini-3.1-flash-lite-preview"

    private let modelOptions = [
        "gemini/gemini-3.1-pro-preview",       // Flagship reasoning
        "gemini/gemini-3-flash-preview",       // Fast, high-performance
        "gemini/gemini-3.1-flash-lite-preview" // Ultra-fast, cost-optimized
    ]

    var body: some View {
        Form {
            Section {
                TextField(
                    "Host",
                    text: $viewModel.backendHost,
                    prompt: Text("http://localhost:8000")
                )
                .textContentType(.URL)

                if !viewModel.backendStatusMessage.isEmpty {
                    Label(
                        viewModel.backendStatusMessage,
                        systemImage: viewModel.backendStatusIsError ? "xmark.circle" : "checkmark.circle"
                    )
                    .foregroundStyle(
                        viewModel.backendStatusIsError ? .red : .green
                    )
                    .font(.caption)
                }

                if viewModel.savedBackendHost {
                    Label("Saved.", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.caption)
                }

                HStack {
                    Spacer()
                    Button(
                        viewModel.isVerifyingBackendHost ? "Verifying..." : "Save"
                    ) {
                        Task { await viewModel.saveBackendHost() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        viewModel.backendHost
                            .trimmingCharacters(in: .whitespaces).isEmpty
                        || viewModel.isVerifyingBackendHost
                    )
                }
            } header: {
                Text("Backend Host")
            } footer: {
                Text(
                    "The URL of your Cuyor backend. Leave as default when running locally."
                )
            }

            Section {
                Picker("Model", selection: $selectedModelOption) {
                    ForEach(modelOptions, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .onChange(of: selectedModelOption) { _, value in
                    viewModel.llmModel = value
                }
                .onAppear {
                    if modelOptions.contains(viewModel.llmModel) {
                        selectedModelOption = viewModel.llmModel
                    } else {
                        selectedModelOption = "gemini/gemini-3.1-flash-lite-preview"
                        viewModel.llmModel = selectedModelOption
                    }
                }

                SecureField(
                    "API Key",
                    text: $viewModel.llmAPIKey,
                    prompt: Text("API Key")
                )
                .textContentType(.password)

                TextField(
                    "Temperature",
                    text: $viewModel.llmTemperature,
                    prompt: Text("0.0 - 2.0")
                )
                TextField(
                    "Top P",
                    text: $viewModel.llmTopP,
                    prompt: Text("0.0 - 1.0")
                )
                TextField(
                    "Max Tokens",
                    text: $viewModel.llmMaxTokens,
                    prompt: Text(">= 1")
                )
                TextField(
                    "Timeout",
                    text: $viewModel.llmTimeout,
                    prompt: Text("seconds > 0")
                )

                if !viewModel.llmStatusMessage.isEmpty {
                    Label(
                        viewModel.llmStatusMessage,
                        systemImage: viewModel.llmStatusIsError ? "xmark.circle" : "checkmark.circle"
                    )
                    .foregroundStyle(viewModel.llmStatusIsError ? .red : .green)
                    .font(.caption)
                }

                HStack {
                    Spacer()
                    Button("Save LLM Config") {
                        viewModel.saveLLMConfig()
                    }
                }
            } header: {
                Text("LLM Defaults")
            } footer: {
                Text(
                    "These are global defaults sent as AnalyzePlanRequest.llm. Leave blank to let backend defaults apply."
                )
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutSettingsView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    var body: some View {
        VStack(spacing: 20) {
            Image("cuyor.prompt.icon")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            VStack(spacing: 4) {
                Text("Cuyor")
                    .font(.title2.weight(.semibold))
                Text("Version \(version) (\(build))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Visual GPS for Mac")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider()
                .frame(maxWidth: 240)

            VStack(spacing: 6) {
                Link("Website", destination: URL(string: "https://cuyor.com")!)
                Link(
                    "Privacy Policy",
                    destination: URL(string: "https://cuyor.com/privacy")!
                )
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
}
