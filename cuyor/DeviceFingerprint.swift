//
//  DeviceFingerprint.swift
//  cuyor
//
//  Created by Cuyor.
//

import Foundation


enum DeviceFingerprint {
    static var current: String {
        if let data = KeychainHelper.shared.read(
            service: CuyorSettingsKey.service,
            account: CuyorSettingsKey.deviceFingerprintAccount
        ),
           let stored = String(data: data, encoding: .utf8),
           !stored.isEmpty {
            return stored
        }

        let generated = UUID().uuidString
        KeychainHelper.shared.save(
            Data(generated.utf8),
            service: CuyorSettingsKey.service,
            account: CuyorSettingsKey.deviceFingerprintAccount
        )
        return generated
    }
}
