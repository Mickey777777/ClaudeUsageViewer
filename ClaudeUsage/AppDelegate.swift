import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var usageVM = UsageViewModel()
    private var suppressNextLeftClick = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "☁ --"
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 180)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: UsageView(vm: usageVM)
        )

        usageVM.onUsageUpdate = { [weak self] session, weekly in
            guard let self else { return }
            let img = makeBarImage(session: session)
            self.statusItem.button?.image = img
            self.statusItem.button?.title = String(format: " %d%%", Int(session))
        }

        usageVM.onTitleChange = { [weak self] title in
            self?.statusItem.button?.image = nil
            self?.statusItem.button?.title = title
        }

        usageVM.refresh()
    }

    @objc func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            suppressNextLeftClick = true
            let menu = NSMenu()
            menu.delegate = self
            menu.addItem(NSMenuItem(title: "↻  새로고침", action: #selector(onRefresh), keyEquivalent: "r"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            if suppressNextLeftClick {
                suppressNextLeftClick = false
                return
            }
            togglePopover()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.suppressNextLeftClick = false
        }
    }

    @objc func onRefresh() {
        usageVM.refresh()
    }

    private func makeBarImage(session: Double) -> NSImage {
        let barW: CGFloat = 5
        let barH: CGFloat = 14
        let imgH: CGFloat = 18

        let image = NSImage(size: NSSize(width: barW, height: imgH), flipped: false) { _ in
            let yOffset = (imgH - barH) / 2
            drawBar(NSRect(x: 0, y: yOffset, width: barW, height: barH), pct: session)
            return true
        }
        image.isTemplate = false
        return image
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

private func drawBar(_ rect: NSRect, pct: Double) {
    let clamped = max(0.0, min(1.0, pct / 100.0))

    NSColor.tertiaryLabelColor.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()

    let fillColor: NSColor = pct >= 80 ? .systemRed : pct >= 50 ? .systemOrange : .systemGreen
    let fillH = rect.height * CGFloat(clamped)
    guard fillH > 0 else { return }
    let fillRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: fillH)
    fillColor.setFill()
    NSBezierPath(roundedRect: fillRect, xRadius: 2, yRadius: 2).fill()
}
