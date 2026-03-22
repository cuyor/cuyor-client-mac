//
//  CuyorAPIClient.swift
//  cuyor
//
//  Created by.
//

import AppKit
import Foundation

final class CuyorAPIClient {

    static let shared = CuyorAPIClient()

    private var baseURL: URL {
        let rawHost = UserDefaults.standard.string(
            forKey: CuyorSettingsKey.backendHost
        ) ?? "http://localhost:8000"
        let host = normalizedHost(rawHost)
        return URL(string: "\(host)/api/v1")!
    }

    // Dedicated session with timeouts
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private init() {}

    struct LicenseActivationResult {
        let email: String
        let plan: String
    }

    enum LicenseError: LocalizedError {
        case alreadyActivatedOnOtherDevice
        case expired
        case invalid
        case notFound
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .alreadyActivatedOnOtherDevice:
                return "This key is already activated on another device."
            case .expired:
                return "Your license key has expired."
            case .invalid:
                return "Invalid license key."
            case .notFound:
                return "License key not found."
            case .serverError(let msg):
                return "Server error: \(msg)"
            }
        }
    }

    enum HealthCheckError: LocalizedError {
        case invalidURL
        case unreachable(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid backend URL."
            case .unreachable(let message):
                return "Health check failed: \(message)"
            }
        }
    }

    func chatPlan(
        query: String,
        image: NSImage?,
        accessibilityTree: SanitizedAXTree?,
        captureRegion: CGRect?
    ) async throws -> CuyorInstructionPlan {
        let request = try buildPlanRequest(
            query: query,
            image: image,
            accessibilityTree: accessibilityTree,
            captureRegion: captureRegion
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            // Capture backend error body so we know what went wrong
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw APIError.badStatus(message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CuyorInstructionPlan.self, from: data)
        } catch {
            throw APIError.invalidPlanResponse
        }
    }

    func activateLicense(
        licenseKey: String,
        deviceFingerprint: String
    ) async throws -> LicenseActivationResult {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("license/activate")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "license_key": licenseKey,
            "device_fingerprint": deviceFingerprint,
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LicenseError.serverError("Invalid response")
        }

        if http.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return LicenseActivationResult(
                email: json?["email"] as? String ?? "",
                plan: json?["plan"] as? String ?? "basic"
            )
        }

        let body = (
            (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"]
            as? String
        ) ?? ""
        switch http.statusCode {
        case 403 where body.lowercased().contains("another device"):
            throw LicenseError.alreadyActivatedOnOtherDevice
        case 403 where body.lowercased().contains("expired"):
            throw LicenseError.expired
        case 403:
            throw LicenseError.invalid
        case 404:
            throw LicenseError.notFound
        default:
            throw LicenseError.serverError(body)
        }
    }

    func validateLicense(
        licenseKey: String,
        deviceFingerprint: String
    ) async throws -> LicenseActivationResult {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("license/validate")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "license_key": licenseKey,
            "device_fingerprint": deviceFingerprint,
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LicenseError.serverError("Invalid response")
        }
        guard http.statusCode == 200 else {
            throw LicenseError.invalid
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return LicenseActivationResult(
            email: json?["email"] as? String ?? "",
            plan: json?["plan"] as? String ?? "basic"
        )
    }

    func verifyBackendHealth(host: String) async throws {
        let normalized = normalizedHost(host)
        guard let url = URL(string: normalized + "/health") else {
            throw HealthCheckError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HealthCheckError.unreachable("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(
                data: data,
                encoding: .utf8
            ) ?? "status \(http.statusCode)"
            throw HealthCheckError.unreachable(body)
        }
    }

    private func normalizedHost(_ raw: String) -> String {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return "http://localhost:8000" }
        if trimmed.contains("://") {
            return trimmed
        }
        return "http://\(trimmed)"
    }

    private func buildPlanRequest(
        query: String,
        image: NSImage?,
        accessibilityTree: SanitizedAXTree?,
        captureRegion: CGRect?
    ) throws -> URLRequest {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("analyze/plan")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let key = KeychainHelper.shared.read(
            service: CuyorSettingsKey.service,
            account: CuyorSettingsKey.licenseAccount
        ) {
            request.setValue(
                String(data: key, encoding: .utf8),
                forHTTPHeaderField: "X-License-Key"
            )
        }

        var body: [String: Any] = ["query": query]

        if let img = image, let b64 = img.base64PNG() {
            body["base64_image"] = b64
            body["image_dimensions"] = [
                "width":  Double(img.size.width),
                "height": Double(img.size.height)
            ]
        } else {
            body["base64_image"]     = NSNull()
            body["image_dimensions"] = NSNull()
        }


        body["accessibility_tree"] = accessibilityTree?.payload ?? NSNull()

        if let llm = buildLLMPayload() {
            body["llm"] = llm
        }


        if let region = captureRegion,
           let screenHeight = NSScreen.main?.frame.height {
            let cgY = screenHeight - region.maxY
            body["capture_region"] = [
                "x":      Double(region.minX),
                "y":      Double(cgY),
                "width":  Double(region.width),
                "height": Double(region.height)
            ]
        } else {
            body["capture_region"] = NSNull()
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildLLMPayload() -> [String: Any]? {
        let store = SettingsStore.shared
        var llm: [String: Any] = [:]

        let model = store.llmModel.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !model.isEmpty {
            llm["model"] = model
        }

        let apiKey = store.llmAPIKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !apiKey.isEmpty {
            llm["api_key"] = apiKey
        }

        if let temperature = store.llmTemperature,
           (0...2).contains(temperature) {
            llm["temperature"] = temperature
        }

        if let topP = store.llmTopP,
           (0...1).contains(topP) {
            llm["top_p"] = topP
        }

        if let maxTokens = store.llmMaxTokens,
           maxTokens >= 1 {
            llm["max_tokens"] = maxTokens
        }

        if let timeout = store.llmTimeout,
           timeout > 0 {
            llm["timeout"] = timeout
        }

        return llm.isEmpty ? nil : llm
    }

    enum APIError: LocalizedError {
        case badStatus(String)
        case invalidPlanResponse

        var errorDescription: String? {
            switch self {
            case .badStatus(let msg):
                return "Backend error: \(msg)"
            case .invalidPlanResponse:
                return "The backend returned an invalid plan response."
            }
        }
    }
}

private extension NSImage {
    func base64PNG() -> String? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let rep  = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return data.base64EncodedString()
    }
}
