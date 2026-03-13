//
//  HotKeyManager.swift
//  cuyor
//
//  Created by Umar Ahmed on 11/03/2026.
//

import Carbon.HIToolbox

extension Notification.Name {
    static let cuyorActivated        = Notification.Name(
        "com.syndrect.cuyor.activated"
    )
    static let cuyorCaptureActivated = Notification.Name(
        "com.syndrect.cuyor.capture"
    )
}

// MARK: - C-compatible event callback (cannot capture Swift closures)

private func hotKeyEventCallback(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    DispatchQueue.main.async {
        switch hotKeyID.id {
        case 1:
            NotificationCenter.default.post(name: .cuyorActivated, object: nil)
        case 2:
            NotificationCenter.default
                .post(name: .cuyorCaptureActivated, object: nil)
        default:
            break
        }
    }
    return noErr
}

// MARK: - Manager

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var captureHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    /// Registers ⌃⌥Space (activate) and ⌃⌥S (capture) as global hotkeys.
    func register() {
        // Carbon modifier flags: controlKey = 0x1000, optionKey = 0x0800
        let modifiers: UInt32 = 0x1000 | 0x0800

        // ⌃⌥Space — toggle Cuyor bar (id = 1)
        var id = EventHotKeyID()
        id.signature = 0x43594F52   // 'CYOR'
        id.id        = 1
        RegisterEventHotKey(49, modifiers, id,   // 49 = kVK_Space
                            GetApplicationEventTarget(), 0, &hotKeyRef)

        // ⌃⌥S — trigger screen capture (id = 2)
        var captureID = EventHotKeyID()
        captureID.signature = 0x43594F52
        captureID.id        = 2
        RegisterEventHotKey(1, modifiers, captureID,  // 1 = kVK_ANSI_S
                            GetApplicationEventTarget(), 0, &captureHotKeyRef)

        // One handler covers both hotkeys because both are kEventHotKeyPressed
        // on the same event target; the callback distinguishes by hotKeyID.id.
        var spec = EventTypeSpec(
            eventClass: UInt32(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1, &spec,
            nil, &eventHandlerRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef          {
            UnregisterEventHotKey(ref); hotKeyRef = nil
        }
        if let ref = captureHotKeyRef   {
            UnregisterEventHotKey(ref); captureHotKeyRef = nil
        }
        if let ref = eventHandlerRef    {
            RemoveEventHandler(ref); eventHandlerRef = nil
        }
    }

    deinit { unregister() }
}
