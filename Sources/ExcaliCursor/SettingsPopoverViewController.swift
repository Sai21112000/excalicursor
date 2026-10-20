import AppKit
import Carbon
import ServiceManagement
import SwiftUI

public final class SettingsPopoverViewController: NSHostingController<SettingsPopoverView> {
    public init(
        hotkeyManager: HotkeyManager = .shared,
        onToggleOverlay: @escaping () -> Void,
        onActivateLaser: @escaping () -> Void = {},
        onClearCanvas: @escaping () -> Void
    ) {
        let rootView = SettingsPopoverView(
            hotkeyManager: hotkeyManager,
            onToggleOverlay: onToggleOverlay,
            onActivateLaser: onActivateLaser,
            onClearCanvas: onClearCanvas
        )
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public struct SettingsPopoverView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    var onToggleOverlay: () -> Void
    var onActivateLaser: () -> Void
    var onClearCanvas: () -> Void

    @State private var eventMonitor: Any?
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @State private var launchAtLoginError: String?

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "scribble.variable")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ExcaliCursor")
                        .font(.system(size: 14, weight: .bold))
                    Text("Excalidraw + Laser Pointer Overlay")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Laser (K)") {
                    onActivateLaser()
                }
                .controlSize(.small)

                Button("Toggle") {
                    onToggleOverlay()
                }
                .controlSize(.small)
            }

            Divider()

            // Trigger Mode Selection
            VStack(alignment: .leading, spacing: 6) {
                Text("Activation Trigger")
                    .font(.system(size: 12, weight: .semibold))

                Picker("Trigger Mode", selection: $hotkeyManager.triggerMode) {
                    ForEach(HotkeyTriggerMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            // Standard Key Combination Configuration
            if hotkeyManager.triggerMode != .doubleTapOptionOnly {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Global Hotkey:")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Button(action: {
                            toggleShortcutRecording()
                        }) {
                            Text(hotkeyButtonTitle)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .frame(minWidth: 96)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(hotkeyButtonTint)
                        .controlSize(.small)
                    }

                    HStack(spacing: 6) {
                        Text("Presets:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Button("⌘ ⇧ D") {
                            stopRecordingShortcut()
                            hotkeyManager.keyCombo = .cmdShiftD
                        }
                        .controlSize(.mini)

                        Button("⌘ D") {
                            stopRecordingShortcut()
                            hotkeyManager.keyCombo = .cmdD
                        }
                        .controlSize(.mini)

                        Button("⌥ D") {
                            stopRecordingShortcut()
                            hotkeyManager.keyCombo = .optionD
                        }
                        .controlSize(.mini)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)
            }

            // Double-Tap Option Configuration
            if hotkeyManager.triggerMode != .shortcutOnly {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Double-Tap ⌥ Option Speed")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(Int(hotkeyManager.doubleTapInterval * 1000)) ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $hotkeyManager.doubleTapInterval, in: 0.18...0.50, step: 0.02)
                        .controlSize(.small)

                    if hotkeyManager.needsAccessibilityForDoubleTap {
                        Text("Double-tap Option needs Accessibility permission to work in other apps. Keyboard shortcuts do not.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open Accessibility Settings") {
                            HotkeyManager.openAccessibilitySettings()
                        }
                        .controlSize(.small)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)
            }

            Divider()

            // Pass-Through & Startup Preferences
            VStack(alignment: .leading, spacing: 8) {
                Text("Overlay & System Behavior")
                    .font(.system(size: 12, weight: .semibold))

                Toggle("Keep drawings visible when deactivated (click-through)", isOn: Binding(
                    get: { !hotkeyManager.hideDrawingsWhenInactive },
                    set: { hotkeyManager.hideDrawingsWhenInactive = !$0 }
                ))
                .font(.system(size: 12))

                Toggle("Clear canvas automatically when deactivated", isOn: $hotkeyManager.clearOnDeactivate)
                    .font(.system(size: 12))

                Toggle("Launch ExcaliCursor at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                            launchAtLogin = (SMAppService.mainApp.status == .enabled)
                            launchAtLoginError = nil
                        } catch {
                            launchAtLogin = (SMAppService.mainApp.status == .enabled)
                            launchAtLoginError = error.localizedDescription
                        }
                    }
                ))
                .font(.system(size: 12))

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            // Quick Shortcuts Legend
            VStack(alignment: .leading, spacing: 4) {
                Text("Excalidraw Toolbar & Adaptive Dock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("V Select • R Rect • D Diamond • O Ellipse • A Arrow • L Line")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                Text("P Draw • T Text • E Eraser • K Laser • C Clear • ⌘C Copy PNG")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                Text("Drag grip to Left/Right edge for Vertical dock, Top/Bottom for Horizontal.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Clear Canvas") {
                    onClearCanvas()
                }
                .controlSize(.small)

                Spacer()

                Button("Quit ExcaliCursor") {
                    NSApplication.shared.terminate(nil)
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 350)
        .onAppear {
            hotkeyManager.reconfigureHotkeys()
        }
        .onDisappear {
            stopRecordingShortcut()
        }
    }

    private var hotkeyButtonTitle: String {
        if hotkeyManager.isRecordingShortcut { return "Press keys..." }
        if let hotkeyRegistrationError = hotkeyManager.hotkeyRegistrationError {
            return hotkeyRegistrationError
        }
        return hotkeyManager.keyCombo.displayString
    }

    private var hotkeyButtonTint: Color {
        if hotkeyManager.isRecordingShortcut { return .orange }
        if hotkeyManager.hotkeyRegistrationError != nil { return .red }
        return .accentColor
    }

    private func toggleShortcutRecording() {
        if hotkeyManager.isRecordingShortcut {
            stopRecordingShortcut()
        } else {
            startRecordingShortcut()
        }
    }

    private func startRecordingShortcut() {
        hotkeyManager.isRecordingShortcut = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecordingShortcut()
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let carbonMods = KeyCombo.carbonModifiers(from: flags)
            guard carbonMods != 0 else {
                NSSound.beep()
                return nil
            }

            hotkeyManager.keyCombo = KeyCombo(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: carbonMods
            )
            stopRecordingShortcut()
            return nil
        }
    }

    private func stopRecordingShortcut() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if hotkeyManager.isRecordingShortcut {
            hotkeyManager.isRecordingShortcut = false
        }
    }
}
