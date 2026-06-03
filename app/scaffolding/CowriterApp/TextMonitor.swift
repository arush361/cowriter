// ⚠️ UNVERIFIED SCAFFOLDING — never compiled or run. See ../README.md.
//
// Reads the focused text field across apps via the Accessibility API and emits
// a CowriterCore `EditingContext`. Also exposes the caret rectangle (for the
// overlay) and a commit() that inserts accepted text. This is the Phase 2 edge.
//
// Requires the Accessibility permission. Every AX call is `// VERIFY:` because
// the exact attribute behavior varies by app and macOS version.

import AppKit
import ApplicationServices
import CowriterCore

final class TextMonitor {
    /// Called whenever the focused field's text or caret changes.
    var onContextChange: ((EditingContext) -> Void)?

    /// Screen-space caret rectangle for the current field (for the overlay).
    private(set) var caretRect: CGRect = .zero

    private var observer: AXObserver?
    private var focusedElement: AXUIElement?

    /// Whether this process is trusted for Accessibility. Drives onboarding.
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility permission (opens System Settings).
    func requestAccessibilityPermission() {
        // Use the literal key string to avoid referencing the global
        // `kAXTrustedCheckOptionPrompt` (not concurrency-safe under Swift 6).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func start() {
        // VERIFY: observe NSWorkspace.didActivateApplicationNotification to
        // re-attach the AXObserver to whatever app becomes frontmost.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            self?.attachToFrontmostApp(note)
        }
        attachToCurrentFrontmost()
    }

    // MARK: - Attaching to the focused element

    private func attachToCurrentFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        attach(toPID: app.processIdentifier)
    }

    private func attachToFrontmostApp(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        attach(toPID: app.processIdentifier)
    }

    private func attach(toPID pid: pid_t) {
        // VERIFY: create an AXObserver for the app and subscribe to
        // focused-UI-element-changed + value-changed + selected-text-changed.
        let appElement = AXUIElementCreateApplication(pid)
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<TextMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.readFocusedField()
        }
        guard AXObserverCreate(pid, callback, &observer) == .success,
              let observer else { return }
        self.observer = observer

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notif in [kAXFocusedUIElementChangedNotification,
                      kAXValueChangedNotification,
                      kAXSelectedTextChangedNotification] {
            AXObserverAddNotification(observer, appElement, notif as CFString, refcon) // VERIFY
        }
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        readFocusedField()
    }

    // MARK: - Reading

    private func readFocusedField() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement, kAXFocusedUIElementAttribute as CFString, &focused
        ) == .success, let element = focused as! AXUIElement? else { return }
        focusedElement = element

        // Secure field? Never engage. VERIFY: role/subrole detection per app.
        if isSecure(element) {
            onContextChange?(EditingContext(
                appBundleID: app.bundleIdentifier ?? "",
                appName: app.localizedName,
                fieldText: "", caretOffset: 0, isSecure: true
            ))
            return
        }

        let text = stringValue(element, kAXValueAttribute) ?? ""
        let caret = selectedRangeLocation(element) ?? text.utf16.count
        caretRect = caretBounds(element, at: caret) ?? .zero

        onContextChange?(EditingContext(
            appBundleID: app.bundleIdentifier ?? "",
            appName: app.localizedName,
            fieldText: text,
            caretOffset: caret,
            isSecure: false
        ))
    }

    private func isSecure(_ element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        // VERIFY: secure fields report role "AXTextField" with a secure subrole,
        // or a dedicated secure role depending on the app/toolkit.
        return (role as? String) == "AXSecureTextField"
    }

    private func stringValue(_ element: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private func selectedRangeLocation(_ element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &value
        ) == .success, let axValue = value else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axValue as! AXValue, .cfRange, &range) else { return nil }
        return range.location
    }

    /// Caret rectangle in screen coordinates via the bounds-for-range param attr.
    private func caretBounds(_ element: AXUIElement, at offset: Int) -> CGRect? {
        var range = CFRange(location: offset, length: 0)
        guard let axRange = AXValueCreate(.cfRange, &range) else { return nil }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            axRange, &result
        ) == .success, let value = result else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
        return rect // VERIFY: coordinate space + multi-display / Retina handling
    }

    // MARK: - Commit accepted text

    func commit(_ text: String) {
        guard let element = focusedElement else { return }
        // VERIFY: prefer mutating the AX value where supported; otherwise fall
        // back to synthesizing keystrokes via CGEvent. Behavior differs per app.
        let current = stringValue(element, kAXValueAttribute) ?? ""
        let newValue = current + text // simplification: append at caret end
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFTypeRef)
    }
}
