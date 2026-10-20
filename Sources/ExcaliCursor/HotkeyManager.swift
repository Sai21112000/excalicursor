import AppKit
import Carbon
import Combine

public enum HotkeyTriggerMode: String, CaseIterable, Identifiable {
    case both = "both"
    case shortcutOnly = "shortcutOnly"
    case doubleTapOptionOnly = "doubleTapOptionOnly"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .both:
            return "Shortcut + Double-Tap Option"
        case .shortcutOnly:
            return "Keyboard Shortcut Only"
        case .doubleTapOptionOnly:
            return "Double-Tap Option Only"
        }
    }
}

public struct KeyCombo: Equatable, Codable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    public static let cmdShiftD = KeyCombo(
        keyCode: UInt32(kVK_ANSI_D),
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )

    public static let cmdD = KeyCombo(
        keyCode: UInt32(kVK_ANSI_D),
        carbonModifiers: UInt32(cmdKey)
    )

    public static let optionD = KeyCombo(
        keyCode: UInt32(kVK_ANSI_D),
        carbonModifiers: UInt32(optionKey)
    )

    public var displayString: String {
        var parts: [String] = []
        if (carbonModifiers & UInt32(controlKey)) != 0 { parts.append("⌃") }
        if (carbonModifiers & UInt32(optionKey)) != 0 { parts.append("⌥") }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { parts.append("⇧") }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: " ")
    }

    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }

    public static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_ANSI_Grave: return "`"
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        default: return "Key(\(keyCode))"
        }
    }
}

private func carbonHotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.handleCarbonHotKeyTriggered()
    }
    return noErr
}

public final class HotkeyManager: ObservableObject {
    public static let shared = HotkeyManager()

    private enum DefaultsKey {
        static let triggerMode = "ExcaliCursor.triggerMode"
        static let keyCode = "ExcaliCursor.keyCode"
        static let carbonModifiers = "ExcaliCursor.carbonModifiers"
        static let doubleTapInterval = "ExcaliCursor.doubleTapInterval"
        static let clearOnDeactivate = "ExcaliCursor.clearOnDeactivate"
        static let hideDrawingsWhenInactive = "ExcaliCursor.hideDrawingsWhenInactive"
        static let didPromptAccessibility = "ExcaliCursor.didPromptAccessibility"
    }

    @Published public var triggerMode: HotkeyTriggerMode {
        didSet {
            UserDefaults.standard.set(triggerMode.rawValue, forKey: DefaultsKey.triggerMode)
            reconfigureHotkeys()
            onActivationChanged?()
        }
    }

    @Published public var keyCombo: KeyCombo {
        didSet {
            guard !suppressKeyComboWrite else { return }
            UserDefaults.standard.set(Int(keyCombo.keyCode), forKey: DefaultsKey.keyCode)
            UserDefaults.standard.set(Int(keyCombo.carbonModifiers), forKey: DefaultsKey.carbonModifiers)
            reconfigureHotkeys()
            onActivationChanged?()
        }
    }

    @Published public var doubleTapInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(doubleTapInterval, forKey: DefaultsKey.doubleTapInterval)
        }
    }

    @Published public var clearOnDeactivate: Bool {
        didSet {
            UserDefaults.standard.set(clearOnDeactivate, forKey: DefaultsKey.clearOnDeactivate)
        }
    }

    @Published public var hideDrawingsWhenInactive: Bool {
        didSet {
            UserDefaults.standard.set(hideDrawingsWhenInactive, forKey: DefaultsKey.hideDrawingsWhenInactive)
            onPreferenceChanged?()
        }
    }

    @Published public var isRecordingShortcut: Bool = false
    @Published public var hotkeyRegistrationError: String?
    @Published public var needsAccessibilityForDoubleTap: Bool = false

    public var onToggleRequested: (() -> Void)?
    public var onPreferenceChanged: (() -> Void)?
    public var onActivationChanged: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var lastGoodCombo: KeyCombo?
    private var suppressKeyComboWrite = false
    private var didScheduleAccessibilityPrompt = false

    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?

    // State for Double-Tap Option detection
    private var optionIsDown: Bool = false
    private var lastOptionReleaseTime: TimeInterval = 0
    private var otherKeyPressedDuringOption: Bool = false

    private init() {
        let defaults = UserDefaults.standard

        if let rawMode = defaults.string(forKey: DefaultsKey.triggerMode),
           let mode = HotkeyTriggerMode(rawValue: rawMode) {
            self.triggerMode = mode
        } else {
            self.triggerMode = .both
        }

        if defaults.object(forKey: DefaultsKey.keyCode) != nil {
            let code = UInt32(defaults.integer(forKey: DefaultsKey.keyCode))
            let mods = UInt32(defaults.integer(forKey: DefaultsKey.carbonModifiers))
            self.keyCombo = KeyCombo(keyCode: code, carbonModifiers: mods)
        } else {
            self.keyCombo = .cmdShiftD
        }

        let interval = defaults.double(forKey: DefaultsKey.doubleTapInterval)
        self.doubleTapInterval = interval > 0 ? interval : 0.32

        self.clearOnDeactivate = defaults.bool(forKey: DefaultsKey.clearOnDeactivate)
        self.hideDrawingsWhenInactive = defaults.bool(forKey: DefaultsKey.hideDrawingsWhenInactive)

        installCarbonEventHandlerIfNeeded()
        reconfigureHotkeys()
    }

    deinit {
        unregisterCarbonHotKey()
        removeOptionMonitors()
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    public func reconfigureHotkeys() {
        unregisterCarbonHotKey()
        removeOptionMonitors()

        switch triggerMode {
        case .both:
            registerCarbonHotKey()
            installOptionMonitors()
        case .shortcutOnly:
            registerCarbonHotKey()
            setNeedsAccessibility(false)
        case .doubleTapOptionOnly:
            if hotkeyRegistrationError != nil {
                hotkeyRegistrationError = nil
            }
            installOptionMonitors()
        }
    }

    fileprivate func handleCarbonHotKeyTriggered() {
        guard !isRecordingShortcut else { return }
        onToggleRequested?()
    }

    // MARK: - Carbon Global Shortcut Registration

    private func installCarbonEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
    }

    private func registerCarbonHotKey() {
        unregisterCarbonHotKey()

        if tryRegister(keyCombo) == noErr {
            lastGoodCombo = keyCombo
            if hotkeyRegistrationError != nil {
                hotkeyRegistrationError = nil
            }
            return
        }

        hotkeyRegistrationError = "\(keyCombo.displayString) is already in use"
        guard let fallback = lastGoodCombo, fallback != keyCombo else { return }
        guard tryRegister(fallback) == noErr else { return }

        suppressKeyComboWrite = true
        keyCombo = fallback
        UserDefaults.standard.set(Int(fallback.keyCode), forKey: DefaultsKey.keyCode)
        UserDefaults.standard.set(Int(fallback.carbonModifiers), forKey: DefaultsKey.carbonModifiers)
        suppressKeyComboWrite = false
    }

    private func tryRegister(_ combo: KeyCombo) -> OSStatus {
        let hotKeyID = EventHotKeyID(
            signature: OSType(0x45584343), // 'EXCC'
            id: 1
        )
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        } else {
            hotKeyRef = nil
        }
        return status
    }

    public static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func unregisterCarbonHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    // MARK: - Double-Tap Option Detection

    private func installOptionMonitors() {
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.otherKeyPressedDuringOption = true
        }

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.otherKeyPressedDuringOption = true
            return event
        }

        let missingGlobalMonitor = globalFlagsMonitor == nil
        setNeedsAccessibility(missingGlobalMonitor)
        if missingGlobalMonitor {
            promptForAccessibilityIfNeeded()
        }
    }

    private func setNeedsAccessibility(_ needed: Bool) {
        if needsAccessibilityForDoubleTap != needed {
            needsAccessibilityForDoubleTap = needed
        }
    }

    private func promptForAccessibilityIfNeeded() {
        guard needsAccessibilityForDoubleTap else { return }
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.didPromptAccessibility) else { return }
        guard !didScheduleAccessibilityPrompt else { return }
        didScheduleAccessibilityPrompt = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.needsAccessibilityForDoubleTap else { return }
            guard !UserDefaults.standard.bool(forKey: DefaultsKey.didPromptAccessibility) else { return }
            UserDefaults.standard.set(true, forKey: DefaultsKey.didPromptAccessibility)
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Double-Tap Option Needs Accessibility"
            alert.informativeText = "macOS only delivers double-tap Option while other apps are in front if ExcaliCursor is allowed in Accessibility. Keyboard shortcuts keep working without it."
            alert.addButton(withTitle: "Open Accessibility Settings")
            alert.addButton(withTitle: "Not Now")
            if alert.runModal() == .alertFirstButtonReturn {
                Self.openAccessibilitySettings()
            }
        }
    }

    private func removeOptionMonitors() {
        if let monitor = globalFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            globalFlagsMonitor = nil
        }
        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsMonitor = nil
        }
        if let monitor = globalKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyDownMonitor = nil
        }
        if let monitor = localKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyDownMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard !isRecordingShortcut else { return }

        // Only react to Option key codes (58 = Left Option, 61 = Right Option)
        guard event.keyCode == 58 || event.keyCode == 61 else {
            otherKeyPressedDuringOption = true
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let otherModifiers: NSEvent.ModifierFlags = [.command, .control, .shift]

        if !flags.intersection(otherModifiers).isEmpty {
            otherKeyPressedDuringOption = true
            optionIsDown = false
            return
        }

        let isOptionCurrentlyPressed = flags.contains(.option)
        let now = ProcessInfo.processInfo.systemUptime

        if isOptionCurrentlyPressed && !optionIsDown {
            // Option key pressed down
            optionIsDown = true
            otherKeyPressedDuringOption = false
        } else if !isOptionCurrentlyPressed && optionIsDown {
            // Option key released
            optionIsDown = false

            if !otherKeyPressedDuringOption {
                let delta = now - lastOptionReleaseTime
                if delta > 0.04 && delta <= doubleTapInterval {
                    lastOptionReleaseTime = 0
                    DispatchQueue.main.async { [weak self] in
                        self?.onToggleRequested?()
                    }
                } else {
                    lastOptionReleaseTime = now
                }
            } else {
                lastOptionReleaseTime = 0
            }
        }
    }
}
