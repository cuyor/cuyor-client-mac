//
//  AccessibilityTreeManager.swift
//  cuyor
//
//  Created by Cuyor.
//

import AppKit
import ApplicationServices
import Foundation

struct SanitizedAXTree {
    let payload: [String: Any]

    fileprivate init(payload: [String: Any]) {
        self.payload = payload
    }
}

final class AccessibilityTreeManager {
    static let shared = AccessibilityTreeManager()

    private let maxDepth = 6
    private let maxNodesPerApp = 150
    private let cuyorBundleID = "com.syndrect.cuyor"
    private let pathMarkers = [
        "/users/",
        "/documents/",
        "/desktop/",
        ".app",
        ".pdf",
        ".docx"
    ]
    private let pathRegex = try! NSRegularExpression(
        pattern: #"([A-Za-z]:\\|/)[^\s]+/[^\s]+"#
    )
    private let interactiveTitleRoles: Set<String> = [
        "AXButton",
        "AXMenuButton",
        "AXMenuItem",
        "AXPopUpButton",
        "AXCheckBox",
        "AXRadioButton",
        "AXTab",
        "AXLink",
        "AXDisclosureTriangle",
        "AXIncrementor",
        "AXSlider",
        "AXComboBox",
        "AXToolbarButton"
    ]

    private init() {}

    func isPermissionGranted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func listDetectedApps() -> [(name: String, bundleID: String)] {
        NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular &&
                $0.bundleIdentifier != cuyorBundleID
            }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return (name: name, bundleID: bundleID)
            }
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    ) == .orderedAscending
            }
    }

    func captureTreeJSON(bundleID: String? = nil) async -> SanitizedAXTree? {
        captureTreeSync(bundleID: bundleID)
    }

    private func captureTreeSync(bundleID: String? = nil) -> SanitizedAXTree? {
        guard isPermissionGranted(prompt: false) else {
            return nil
        }

        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular &&
            $0.bundleIdentifier != cuyorBundleID &&
            (bundleID == nil || $0.bundleIdentifier == bundleID)
        }

        var appTrees: [[String: Any]] = []

        for app in runningApps {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var nodeBudget = maxNodesPerApp
            guard let rootNode = buildNode(
                element: appElement,
                depth: 0,
                maxDepth: maxDepth,
                nodeBudget: &nodeBudget
            ) else { continue }

            guard rootNode["children"] != nil else { continue }

            appTrees.append([
                "app": [
                    "bundle_id": app.bundleIdentifier ?? "unknown",
                    "pid": app.processIdentifier,
                    "localized_name": app.localizedName ?? "unknown"
                ],
                "root": rootNode
            ])
        }

        guard !appTrees.isEmpty else { return nil }

        return SanitizedAXTree(payload: [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "apps": appTrees
        ])
    }

    private func buildNode(
        element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        nodeBudget: inout Int
    ) -> [String: Any]? {
        guard nodeBudget > 0 else { return nil }
        nodeBudget -= 1

        var rawNode: [String: Any] = [
            "role": value(
                for: kAXRoleAttribute as CFString,
                in: element
            ) as Any,
            "title": value(
                for: kAXTitleAttribute as CFString,
                in: element
            ) as Any,
            "identifier": value(
                for: kAXIdentifierAttribute as CFString,
                in: element
            ) as Any,
            "placeholder_value": value(
                for: kAXPlaceholderValueAttribute as CFString,
                in: element
            ) as Any,
            "enabled": boolValue(
                for: kAXEnabledAttribute as CFString,
                in: element
            ) as Any,
            "focused": boolValue(
                for: kAXFocusedAttribute as CFString,
                in: element
            ) as Any
        ]

        if let frame = frame(for: element) {
            rawNode["frame"] = [
                "x": Int(frame.origin.x),
                "y": Int(frame.origin.y),
                "width": Int(frame.size.width),
                "height": Int(frame.size.height)
            ]
        }

        var node = sanitizeNode(rawNode)

        guard depth < maxDepth,
              let children = children(of: element),
              !children.isEmpty else {
            return node
        }

        var childNodes: [[String: Any]] = []
        childNodes.reserveCapacity(children.count)

        for child in children {
            if nodeBudget <= 0 { break }
            if let childNode = buildNode(
                element: child,
                depth: depth + 1,
                maxDepth: maxDepth,
                nodeBudget: &nodeBudget
            ) {
                childNodes.append(childNode)
            }
        }

        if !childNodes.isEmpty {
            node["children"] = childNodes
        }

        return node
    }

    private func sanitizeNode(_ rawNode: [String: Any]) -> [String: Any] {
        var node: [String: Any] = [:]

        let role = (rawNode["role"] as? String)?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let role, !role.isEmpty {
            node["role"] = role
        }

        if let identifier = sanitizedRetainedString(
            rawNode["identifier"] as? String
        ) {
            node["identifier"] = identifier
        }

        if let placeholder = sanitizedRetainedString(
            rawNode["placeholder_value"] as? String
        ) {
            node["placeholder_value"] = placeholder
        }

        if let enabled = rawNode["enabled"] as? Bool {
            node["enabled"] = enabled
        }

        if let focused = rawNode["focused"] as? Bool {
            node["focused"] = focused
        }

        if let frame = rawNode["frame"] as? [String: Int] {
            node["frame"] = frame
        }

        if let role,
           interactiveTitleRoles.contains(role),
           let title = sanitizedRetainedString(rawNode["title"] as? String) {
            node["title"] = title
        }

        return node
    }

    private func sanitizedRetainedString(_ candidate: String?) -> String? {
        guard let raw = candidate?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ),
              !raw.isEmpty,
              !containsPathLikeContent(raw) else {
            return nil
        }
        return raw
    }

    private func containsPathLikeContent(_ text: String) -> Bool {
        let lower = text.lowercased()

        if lower
            .hasPrefix("/") || lower
            .hasPrefix("~/") || lower
            .contains("://") {
            return true
        }

        if pathMarkers.contains(where: { lower.contains($0) }) {
            return true
        }

        let range = NSRange(lower.startIndex..<lower.endIndex, in: lower)
        return pathRegex.firstMatch(in: lower, options: [], range: range) != nil
    }

    private func value(for attribute: CFString, in element: AXUIElement) -> String? {
        var ref: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &ref)
        guard result == .success, let value = ref else { return nil }

        if CFGetTypeID(value) == CFStringGetTypeID() {
            return value as? String
        }
        if CFGetTypeID(value) == CFNumberGetTypeID() {
            return "\(value)"
        }
        return nil
    }

    private func boolValue(for attribute: CFString, in element: AXUIElement) -> Bool? {
        var ref: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &ref)
        guard result == .success, let value = ref else { return nil }

        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return value as? Bool
        }

        if CFGetTypeID(value) == CFNumberGetTypeID() {
            return (value as? NSNumber)?.boolValue
        }

        return nil
    }

    private func children(of element: AXUIElement) -> [AXUIElement]? {
        var ref: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &ref
        )
        guard result == .success,
              let list = ref as? [AXUIElement] else {
            return nil
        }
        return list
    }

    private func frame(for element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        let posResult = AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionRef
        )
        let sizeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &sizeRef
        )

        guard posResult == .success,
              sizeResult == .success,
              let positionAX = positionRef,
              let sizeAX = sizeRef,
              CFGetTypeID(positionAX) == AXValueGetTypeID(),
              CFGetTypeID(sizeAX) == AXValueGetTypeID() else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        let positionValue = positionAX as! AXValue
        let sizeValue = sizeAX as! AXValue

        guard AXValueGetType(positionValue) == .cgPoint,
              AXValueGetType(sizeValue) == .cgSize,
              AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }
}
