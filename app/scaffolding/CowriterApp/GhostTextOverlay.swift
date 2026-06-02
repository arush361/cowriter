// ⚠️ UNVERIFIED SCAFFOLDING — never compiled or run. See ../README.md.
//
// Renders the suggestion as faint inline ghost text at the caret using a
// borderless, click-through, non-activating panel positioned at the caret rect.
// This is the universal Phase 4 renderer (the `.overlay` strategy); apps marked
// `.directInsertion` in AppCompatibility can use a smoother per-app path later.

import AppKit
import CowriterCore

final class GhostTextOverlay {
    private let panel: NSPanel
    private let label: NSTextField

    init() {
        // Borderless, transparent, floats above other windows, ignores clicks,
        // and never steals key focus from the app the user is typing in.
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar          // VERIFY: above normal windows
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        label = NSTextField(labelWithString: "")
        label.textColor = NSColor.tertiaryLabelColor // the faint "ghost" look
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        panel.contentView = label
    }

    /// Show `text` at the given caret rectangle (screen coordinates).
    /// `rendering` lets the controller pick a strategy per app.
    func show(_ text: String, at caretRect: CGRect, rendering: AppCompatibility.Rendering) {
        guard !text.isEmpty else { hide(); return }
        label.stringValue = text
        label.sizeToFit()

        // Place the ghost text starting at the caret, baseline-aligned.
        // VERIFY: convert caretRect from AX (top-left origin) to AppKit
        // (bottom-left origin) screen coordinates, and match the field's font.
        let size = label.fittingSize
        let origin = CGPoint(x: caretRect.maxX, y: caretRect.minY)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        label.stringValue = ""
        panel.orderOut(nil)
    }
}
