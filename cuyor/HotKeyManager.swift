//
//  HotKeyManager.swift
//  cuyor
//
//  Created by Umar Ahmed on 11/03/2026.
//

import Carbon.HIToolbox

extension Notification.Name {
    static let cuyorActivated = Notification.Name("com.syndrect.cuyor.activated")
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
    if hotKeyID.id == 1 {
        // Dispatch to main thread; Carbon callbacks may come from any thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cuyorActivated, object: nil)
        }
    }
    return noErr
}

// MARK: - Manager

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    /// Registers ⌃⌥Space as the global activation hotkey.
    func register() {
        // Carbon modifier flags: controlKey = 0x1000, optionKey = 0x0800
        // ⌃⌥Space has no macOS system conflict (⌥⌘Space opens Finder search).
        let modifiers: UInt32 = 0x1000 | 0x0800
        let keyCode: UInt32   = 49          // kVK_Space

        var id = EventHotKeyID()
        id.signature = 0x43594F52           // 'CYOR'
        id.id        = 1

        RegisterEventHotKey(
            keyCode, modifiers, id,
            GetApplicationEventTarget(),
            0, &hotKeyRef
        )

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
        if let ref = hotKeyRef       { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
    }

    deinit { unregister() }
}
