//
//  HotKeyManager.swift
//  cuyor
//
//  Created by Cuyor.
//

import Carbon.HIToolbox

extension Notification.Name {
    static let cuyorActivated        = Notification.Name(
        "com.cuyor.activated"
    )
    static let cuyorCaptureActivated = Notification.Name(
        "com.cuyor.capture"
    )
}


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
        let modifiers: UInt32 = 0x1000 | 0x0800

        var id = EventHotKeyID()
        id.signature = 0x43594F52
        id.id        = 1
        RegisterEventHotKey(49, modifiers, id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)

        var captureID = EventHotKeyID()
        captureID.signature = 0x43594F52
        captureID.id        = 2
        RegisterEventHotKey(1, modifiers, captureID,
                            GetApplicationEventTarget(), 0, &captureHotKeyRef)

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
