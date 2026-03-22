//
//  SettingsStore.swift
//  cuyor
//
//  Created by Cuyor.
//

import Foundation

enum CuyorSettingsKey {
    static let service = "cuyor"
    static let licenseAccount = "licenseKey"
    static let deviceFingerprintAccount = "deviceFingerprint"
    static let llmAPIKeyAccount = "llmApiKey"

    static let userEmail = "userEmail"
    static let licensePlan = "licensePlan"
    static let backendHost = "backendHost"
    static let llmModel = "llmModel"
    static let llmTemperature = "llmTemperature"
    static let llmTopP = "llmTopP"
    static let llmMaxTokens = "llmMaxTokens"
    static let llmTimeout = "llmTimeout"
}

final class SettingsStore {
    static let shared = SettingsStore()
    private init() {}

    var backendHost: String {
        get {
            UserDefaults.standard.string(forKey: CuyorSettingsKey.backendHost)
            ?? "http://localhost:8000"
        }
        set {
            UserDefaults.standard
                .set(newValue, forKey: CuyorSettingsKey.backendHost)
        }
    }

    var userEmail: String {
        get {
            UserDefaults.standard
                .string(forKey: CuyorSettingsKey.userEmail) ?? ""
        }
        set {
            UserDefaults.standard
                .set(newValue, forKey: CuyorSettingsKey.userEmail)
        }
    }

    var licensePlan: String {
        get {
            UserDefaults.standard
                .string(forKey: CuyorSettingsKey.licensePlan) ?? ""
        }
        set {
            UserDefaults.standard
                .set(newValue, forKey: CuyorSettingsKey.licensePlan)
        }
    }

    var licenseKey: String {
        get {
            guard
                let data = KeychainHelper.shared.read(
                    service: CuyorSettingsKey.service,
                    account: CuyorSettingsKey.licenseAccount
                ),
                let key = String(data: data, encoding: .utf8)
            else {
                return ""
            }
            return key
        }
        set {
            let trimmed = newValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if trimmed.isEmpty {
                KeychainHelper.shared.delete(
                    service: CuyorSettingsKey.service,
                    account: CuyorSettingsKey.licenseAccount
                )
                return
            }
            KeychainHelper.shared.save(
                Data(trimmed.utf8),
                service: CuyorSettingsKey.service,
                account: CuyorSettingsKey.licenseAccount
            )
        }
    }

    var llmModel: String {
        get {
            UserDefaults.standard
                .string(forKey: CuyorSettingsKey.llmModel) ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if trimmed.isEmpty {
                UserDefaults.standard
                    .removeObject(forKey: CuyorSettingsKey.llmModel)
            } else {
                UserDefaults.standard
                    .set(trimmed, forKey: CuyorSettingsKey.llmModel)
            }
        }
    }

    var llmTemperature: Double? {
        get {
            UserDefaults.standard
                .object(forKey: CuyorSettingsKey.llmTemperature) as? Double
        }
        set {
            if let newValue {
                UserDefaults.standard
                    .set(newValue, forKey: CuyorSettingsKey.llmTemperature)
            } else {
                UserDefaults.standard
                    .removeObject(forKey: CuyorSettingsKey.llmTemperature)
            }
        }
    }

    var llmTopP: Double? {
        get {
            UserDefaults.standard
                .object(forKey: CuyorSettingsKey.llmTopP) as? Double
        }
        set {
            if let newValue {
                UserDefaults.standard
                    .set(newValue, forKey: CuyorSettingsKey.llmTopP)
            } else {
                UserDefaults.standard
                    .removeObject(forKey: CuyorSettingsKey.llmTopP)
            }
        }
    }

    var llmMaxTokens: Int? {
        get {
            UserDefaults.standard
                .object(forKey: CuyorSettingsKey.llmMaxTokens) as? Int
        }
        set {
            if let newValue {
                UserDefaults.standard
                    .set(newValue, forKey: CuyorSettingsKey.llmMaxTokens)
            } else {
                UserDefaults.standard
                    .removeObject(forKey: CuyorSettingsKey.llmMaxTokens)
            }
        }
    }

    var llmTimeout: Double? {
        get {
            UserDefaults.standard
                .object(forKey: CuyorSettingsKey.llmTimeout) as? Double
        }
        set {
            if let newValue {
                UserDefaults.standard
                    .set(newValue, forKey: CuyorSettingsKey.llmTimeout)
            } else {
                UserDefaults.standard
                    .removeObject(forKey: CuyorSettingsKey.llmTimeout)
            }
        }
    }

    var llmAPIKey: String {
        get {
            guard
                let data = KeychainHelper.shared.read(
                    service: CuyorSettingsKey.service,
                    account: CuyorSettingsKey.llmAPIKeyAccount
                ),
                let key = String(data: data, encoding: .utf8)
            else {
                return ""
            }
            return key
        }
        set {
            let trimmed = newValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if trimmed.isEmpty {
                KeychainHelper.shared.delete(
                    service: CuyorSettingsKey.service,
                    account: CuyorSettingsKey.llmAPIKeyAccount
                )
            } else {
                KeychainHelper.shared.save(
                    Data(trimmed.utf8),
                    service: CuyorSettingsKey.service,
                    account: CuyorSettingsKey.llmAPIKeyAccount
                )
            }
        }
    }

    func clearLicenseState() {
        licenseKey = ""
        userEmail = ""
        licensePlan = ""
    }
}
