//
//  SettingsDataFlow.swift
//  cuyor
//
//  Created by Cuyor.
//

import Foundation
import Combine

private enum LLMDefaults {
    static let temperature = 0.2
    static let topP = 1.0
    static let maxTokens = 1024
    static let timeout = 60.0
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var licenseKeyInput: String
    @Published var backendHost: String
    @Published var llmModel: String
    @Published var llmAPIKey: String
    @Published var llmTemperature: String
    @Published var llmTopP: String
    @Published var llmMaxTokens: String
    @Published var llmTimeout: String

    @Published private(set) var userEmail: String
    @Published private(set) var licensePlan: String
    @Published private(set) var statusMessage: String = ""
    @Published private(set) var statusIsError: Bool = false
    @Published private(set) var isActivating: Bool = false
    @Published private(set) var savedBackendHost: Bool = false
    @Published private(set) var backendStatusMessage: String = ""
    @Published private(set) var backendStatusIsError: Bool = false
    @Published private(set) var isVerifyingBackendHost: Bool = false
    @Published private(set) var llmStatusMessage: String = ""
    @Published private(set) var llmStatusIsError: Bool = false

    private let store: SettingsStore
    private let apiClient: CuyorAPIClient

    init(
        store: SettingsStore? = nil,
        apiClient: CuyorAPIClient? = nil
    ) {
        let resolvedStore = store ?? .shared
        let resolvedAPIClient = apiClient ?? .shared

        self.store = resolvedStore
        self.apiClient = resolvedAPIClient
        self.licenseKeyInput = resolvedStore.licenseKey
        self.backendHost = resolvedStore.backendHost
        self.llmModel = resolvedStore.llmModel
        self.llmAPIKey = resolvedStore.llmAPIKey
        self.llmTemperature = resolvedStore.llmTemperature
            .map { String($0) } ?? String(LLMDefaults.temperature)
        self.llmTopP = resolvedStore.llmTopP
            .map { String($0) } ?? String(LLMDefaults.topP)
        self.llmMaxTokens = resolvedStore.llmMaxTokens
            .map { String($0) } ?? String(LLMDefaults.maxTokens)
        self.llmTimeout = resolvedStore.llmTimeout
            .map { String($0) } ?? String(LLMDefaults.timeout)
        self.userEmail = resolvedStore.userEmail
        self.licensePlan = resolvedStore.licensePlan
    }

    var deviceFingerprint: String { DeviceFingerprint.current }
    var isActivated: Bool { !userEmail.isEmpty }

    func activateLicense() async {
        let key = licenseKeyInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !key.isEmpty, !isActivating else { return }

        isActivating = true
        statusMessage = ""

        do {
            let result = try await apiClient.activateLicense(
                licenseKey: key,
                deviceFingerprint: deviceFingerprint
            )
            store.licenseKey = key
            store.userEmail = result.email
            store.licensePlan = result.plan

            userEmail = result.email
            licensePlan = result.plan
            licenseKeyInput = key
            statusMessage = "Activated successfully."
            statusIsError = false
        } catch let error as CuyorAPIClient.LicenseError {
            statusMessage = error.localizedDescription
            statusIsError = true
        } catch {
            statusMessage = "Activation failed. Check your connection."
            statusIsError = true
        }

        isActivating = false
    }

    func deactivateLicense() {
        store.clearLicenseState()
        userEmail = ""
        licensePlan = ""
        licenseKeyInput = ""
        statusMessage = ""
        statusIsError = false
    }

    func saveBackendHost() async {
        let normalized = normalizeBackendHost(backendHost)
        guard !normalized.isEmpty, !isVerifyingBackendHost else { return }

        isVerifyingBackendHost = true
        backendStatusMessage = ""
        backendStatusIsError = false

        do {
            try await apiClient.verifyBackendHealth(host: normalized)
        } catch {
            backendStatusMessage = error.localizedDescription
            backendStatusIsError = true
            isVerifyingBackendHost = false
            return
        }

        store.backendHost = normalized
        backendHost = normalized
        savedBackendHost = true
        backendStatusMessage = "Backend verified successfully."
        backendStatusIsError = false
        isVerifyingBackendHost = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.savedBackendHost = false
            self.backendStatusMessage = ""
        }
    }

    func saveLLMConfig() {
        let model = llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        llmStatusMessage = ""
        llmStatusIsError = false

        let temperature = parseDouble(
            llmTemperature,
            min: 0,
            max: 2,
            fieldName: "Temperature"
        )
        if llmStatusIsError { return }

        let topP = parseDouble(
            llmTopP,
            min: 0,
            max: 1,
            fieldName: "Top P"
        )
        if llmStatusIsError { return }

        let maxTokens = parseInt(
            llmMaxTokens,
            min: 1,
            fieldName: "Max Tokens"
        )
        if llmStatusIsError { return }

        let timeout = parseDoubleStrictGreaterThanZero(
            llmTimeout,
            fieldName: "Timeout"
        )
        if llmStatusIsError { return }

        store.llmModel = model
        store.llmAPIKey = key
        store.llmTemperature = temperature
        store.llmTopP = topP
        store.llmMaxTokens = maxTokens
        store.llmTimeout = timeout

        llmModel = model
        llmAPIKey = key
        llmTemperature = temperature.map { String($0) } ?? ""
        llmTopP = topP.map { String($0) } ?? ""
        llmMaxTokens = maxTokens.map { String($0) } ?? ""
        llmTimeout = timeout.map { String($0) } ?? ""

        llmStatusMessage = "LLM config saved."
        llmStatusIsError = false
    }

    // Called during app launch to sync persisted license state with backend.
    func validateStoredLicenseOnLaunch() async {
        let key = store.licenseKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !key.isEmpty else { return }

        do {
            let result = try await apiClient.validateLicense(
                licenseKey: key,
                deviceFingerprint: deviceFingerprint
            )
            store.userEmail = result.email
            store.licensePlan = result.plan
            userEmail = result.email
            licensePlan = result.plan
        } catch let error as CuyorAPIClient.LicenseError {
            switch error {
            case .invalid, .notFound, .expired, .alreadyActivatedOnOtherDevice:
                store.clearLicenseState()
                userEmail = ""
                licensePlan = ""
                licenseKeyInput = ""
            case .serverError:
                break
            }
        } catch {
            // Keep local license state during transient network failures.
        }
    }

    private func parseDouble(
        _ raw: String,
        min: Double,
        max: Double,
        fieldName: String
    ) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value >= min, value <= max else {
            llmStatusMessage = "\(fieldName) must be between \(min) and \(max)."
            llmStatusIsError = true
            return nil
        }
        return value
    }

    private func parseInt(
        _ raw: String,
        min: Int,
        fieldName: String
    ) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), value >= min else {
            llmStatusMessage = "\(fieldName) must be >= \(min)."
            llmStatusIsError = true
            return nil
        }
        return value
    }

    private func parseDoubleStrictGreaterThanZero(
        _ raw: String,
        fieldName: String
    ) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value > 0 else {
            llmStatusMessage = "\(fieldName) must be > 0."
            llmStatusIsError = true
            return nil
        }
        return value
    }

    private func normalizeBackendHost(_ raw: String) -> String {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return "" }
        if trimmed.contains("://") {
            return trimmed
        }
        return "http://\(trimmed)"
    }
}
