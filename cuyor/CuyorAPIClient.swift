//
//  CuyorAPIClient.swift
//  cuyor
//
//  Created by Umar Ahmed on 12/03/2026.
//

import AppKit
import Foundation

/// Lightweight SSE client for the Cuyor FastAPI backend.
///
/// **API contract (POST /chat):**
/// ```
/// Request  JSON: { "query": "string", "image": "base64string | null" }
/// Response SSE:
///   data: {"token": "hello"}\n\n   (repeated for each streamed token)
///   data: [DONE]\n\n               (terminal frame)
/// ```
final class CuyorAPIClient {

    static let shared = CuyorAPIClient()

    /// Change this if the backend runs on a different host/port.
    let baseURL = URL(string: "http://localhost:8000")!

    private init() {}

    // MARK: - Public

    /// Streams response tokens from the backend.  Each yielded `String` is one
    /// token as returned by the server in `{"token": "..."}` SSE frames.
    func chat(query: String, image: NSImage?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(
                        query: query,
                        image: image
                    )
                    let (bytes, response) = try await URLSession.shared.bytes(
                        for: request
                    )

                    guard let http = response as? HTTPURLResponse,
                          (200...299).contains(http.statusCode) else {
                        throw APIError.badStatus
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        if let token = self.parseToken(from: payload) {
                            continuation.yield(token)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func buildRequest(query: String, image: NSImage?) throws -> URLRequest {
        var request        = URLRequest(
            url: baseURL.appendingPathComponent("chat")
        )
        request.httpMethod = "POST"
        request
            .setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        var body: [String: Any] = ["query": query]
        if let img = image, let b64 = img.base64JPEG() {
            body["image"] = b64
        } else {
            body["image"] = NSNull()
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseToken(from payload: String) -> String? {
        guard
            let data = payload.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
            let token = json["token"]
        else { return nil }
        return token
    }

    // MARK: - Errors

    enum APIError: LocalizedError {
        case badStatus

        var errorDescription: String? {
            switch self {
            case .badStatus: return "The backend returned an unexpected HTTP status."
            }
        }
    }
}

// MARK: - NSImage JPEG encoding

private extension NSImage {
    func base64JPEG(compressionFactor: CGFloat = 0.85) -> String? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(
using: .jpeg,
properties: [.compressionFactor: compressionFactor]
        )
        else { return nil }
        return data.base64EncodedString()
    }
}
