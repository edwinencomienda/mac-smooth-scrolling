import SwiftUI
import AppKit
import CoreGraphics

/// A SwiftUI control that records a modifier-only hotkey (⌘⌥⌃⇧ combinations).
///
/// Click to enter recording mode, press the modifier combo, then release — the last
/// non-empty modifier set becomes the new value. Escape cancels.
/// The value is a CGEventFlags bitmask stored as UInt64.
struct HotkeyRecorder: View {
    @Binding var flagsRaw: UInt64
    var isDisabled: Bool = false

    @State private var recording = false
    @State private var pressedSnapshot: CGEventFlags = []
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleRecording) {
                Text(buttonLabel)
                    .frame(minWidth: 110)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.bordered)
            .disabled(isDisabled)

            if !recording && flagsRaw != 0 {
                Button {
                    flagsRaw = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear hotkey")
                .disabled(isDisabled)
            }
        }
        .onDisappear(perform: stopRecording)
        .onChange(of: isDisabled) { newValue in
            if newValue { stopRecording() }
        }
    }

    private var buttonLabel: String {
        if recording {
            let snap = modifierDisplayString(pressedSnapshot)
            return snap.isEmpty ? "Press modifiers…" : "\(snap) (release to save)"
        }
        if flagsRaw == 0 { return "Click to record" }
        return modifierDisplayString(CGEventFlags(rawValue: flagsRaw))
    }

    private func toggleRecording() {
        if recording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        guard monitor == nil else { return }
        recording = true
        pressedSnapshot = []
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
            // Escape cancels.
            if event.type == .keyDown, event.keyCode == 53 {
                stopRecording()
                return nil
            }
            if event.type == .flagsChanged {
                let cg = toCGFlags(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
                if cg.isEmpty {
                    // All modifiers released — commit the snapshot (if any) and stop.
                    if pressedSnapshot.rawValue != 0 {
                        flagsRaw = pressedSnapshot.rawValue
                    }
                    stopRecording()
                    return nil
                } else {
                    // Record the latest pressed state so the richest combo wins.
                    pressedSnapshot = cg
                    return nil
                }
            }
            return event
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        recording = false
        pressedSnapshot = []
    }

    private func toCGFlags(_ ns: NSEvent.ModifierFlags) -> CGEventFlags {
        var out: CGEventFlags = []
        if ns.contains(.command)  { out.insert(.maskCommand) }
        if ns.contains(.option)   { out.insert(.maskAlternate) }
        if ns.contains(.control)  { out.insert(.maskControl) }
        if ns.contains(.shift)    { out.insert(.maskShift) }
        return out
    }
}
