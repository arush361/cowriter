// ⚠️ UNVERIFIED SCAFFOLDING — never compiled or run. See ../README.md.
//
// A CGEventTap that watches keydowns to: (a) intercept Tab as "accept" while a
// suggestion is visible, and (b) treat any other key as "dismiss" / new input.
// This is the Phase 2/4 input edge. Requires the Accessibility (input
// monitoring) permission. Every CGEvent call is `// VERIFY:`.

import AppKit
import CoreGraphics

final class KeystrokeTap {
    /// Invoked when Tab is pressed while a suggestion is showing. Returning true
    /// from here means we consumed the Tab (it should not reach the app).
    var onAccept: (() -> Void)?
    /// Invoked on any other keydown (user kept typing -> dismiss current ghost).
    var onDismiss: (() -> Void)?

    /// Set by the controller so the tap knows whether a suggestion is on screen.
    /// Only then do we swallow Tab; otherwise Tab passes through normally.
    var suggestionVisible: () -> Bool = { false }

    private var tap: CFMachPort?

    private static let tabKeyCode: CGKeyCode = 48 // VERIFY: kVK_Tab

    func start() {
        let mask = (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<KeystrokeTap>.fromOpaque(refcon).takeUnretainedValue()
            return tap.handle(type: type, event: event)
        }

        // VERIFY: session-level tap, default options, listen-and-modify so we can
        // swallow Tab. Needs the process to be Accessibility-trusted.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == Self.tabKeyCode, suggestionVisible() {
            onAccept?()
            return nil // consume Tab so the app does not also receive it
        }
        // Any other keystroke means the user is still typing: dismiss + let it pass.
        onDismiss?()
        return Unmanaged.passUnretained(event)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
    }
}
