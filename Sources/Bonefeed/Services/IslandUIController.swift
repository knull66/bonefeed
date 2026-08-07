import AppKit
import SwiftUI

/// Floating menu-bar notch + detachable content panel.
@MainActor
final class IslandUIController: NSObject, NSWindowDelegate {
    static let shared = IslandUIController()

    private weak var store: AppStore?
    private var notchPanel: NSPanel?
    private var contentPanel: NSPanel?
    private var screenObserver: NSObjectProtocol?
    private var didPlaceContent = false
    /// Avoid instant close when opening from the non-activating notch.
    private var ignoreResignUntil: Date = .distantPast

    private enum Keys {
        static let pinned = "bonefeed.panelPinned"
        static let contentFrame = "bonefeed.panelFrame" // [x,y,w,h]
    }

    private(set) var isPanelPinned: Bool {
        didSet {
            UserDefaults.standard.set(isPanelPinned, forKey: Keys.pinned)
            applyPinState()
            store?.isPanelPinned = isPanelPinned
        }
    }

    override init() {
        isPanelPinned = UserDefaults.standard.bool(forKey: Keys.pinned)
        super.init()
    }

    func start(store: AppStore) {
        self.store = store
        store.isPanelPinned = isPanelPinned
        store.onTogglePanel = { [weak self] in self?.toggleContentPanel() }
        store.onTogglePin = { [weak self] in self?.togglePin() }
        store.onCollapsePanel = { [weak self] in self?.hideContentPanel(force: false) }

        showNotch()
        // Layout after metrics settle (aux areas / main screen can lag at launch).
        DispatchQueue.main.async { [weak self] in
            self?.repositionNotch()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.repositionNotch()
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.repositionNotch() }
        }
    }

    // MARK: - Notch (lives inside the menu bar strip)

    private func showNotch() {
        guard let store else { return }
        if notchPanel == nil {
            let hosting = NSHostingController(rootView: IslandNotchView(store: store))
            hosting.view.wantsLayer = true
            hosting.view.layer?.backgroundColor = NSColor.clear.cgColor

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 260, height: 24),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = hosting
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            // Above menu bar extras so it’s clickable in the bar.
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isMovable = false
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.animationBehavior = .none
            notchPanel = panel
        }
        repositionNotch()
        notchPanel?.orderFrontRegardless()
    }

    /// Prefer the built-in display that has the camera housing; fall back to main.
    private func notchScreen() -> NSScreen? {
        if let notched = NSScreen.screens.first(where: { screen in
            guard let left = screen.auxiliaryTopLeftArea,
                  let right = screen.auxiliaryTopRightArea
            else { return false }
            return right.minX > left.maxX + 40
        }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    func repositionNotch() {
        guard let panel = notchPanel else { return }
        guard let screen = notchScreen() else { return }

        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
        // Fit inside the menu bar / notch black area (not below it).
        let height = min(24, menuBarHeight - 1)

        // Hardware notch is always horizontally centered — do NOT derive midX from
        // auxiliary areas (menu extras / multi-display can bias them left).
        let midX = screen.frame.midX
        // Wider strip so the horizontal ticker can breathe.
        var width: CGFloat = 320
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           right.minX > left.maxX + 40 {
            let gap = right.minX - left.maxX
            width = min(width, max(200, gap - 10))
        }

        let x = midX - width / 2
        // Flush to the top of the screen, vertically centered in the menu bar band.
        let y = screen.frame.maxY - menuBarHeight + (menuBarHeight - height) / 2

        let frame = NSRect(x: x, y: y, width: width, height: height)
        panel.setFrame(frame, display: true)
        panel.contentView?.frame = NSRect(origin: .zero, size: frame.size)
        panel.orderFrontRegardless()
    }

    // MARK: - Content panel

    func toggleContentPanel() {
        if contentPanel?.isVisible == true {
            hideContentPanel(force: true)
        } else {
            showContentPanel()
        }
    }

    func showContentPanel() {
        guard let store else { return }

        ignoreResignUntil = Date().addingTimeInterval(0.6)
        NSApp.activate(ignoringOtherApps: true)

        if contentPanel == nil {
            let hosting = NSHostingController(rootView: IslandPanelView(store: store))
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
                styleMask: [.titled, .closable, .fullSizeContentView, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = hosting
            panel.title = Brand.name
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isOpaque = true
            panel.backgroundColor = NSColor.black
            panel.isMovableByWindowBackground = true
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.minSize = NSSize(width: 360, height: 480)
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.hidesOnDeactivate = false
            contentPanel = panel
            applyPinState()
            placeContentPanel()
        }

        // Splash each open.
        store.panelOpenToken &+= 1
        store.isPanelOpen = true

        guard let panel = contentPanel else { return }
        if !didPlaceContent {
            placeContentPanel()
        }
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func hideContentPanel(force: Bool) {
        guard let panel = contentPanel, panel.isVisible else {
            store?.isPanelOpen = false
            return
        }
        if isPanelPinned && !force { return }
        persistContentFrame()
        panel.orderOut(nil)
        store?.isPanelOpen = false
    }

    func togglePin() {
        isPanelPinned.toggle()
        ignoreResignUntil = Date().addingTimeInterval(0.4)
        if isPanelPinned {
            // Keep visible and key-capable while pinned.
            contentPanel?.hidesOnDeactivate = false
            contentPanel?.level = .floating
            contentPanel?.orderFrontRegardless()
        } else {
            contentPanel?.level = .normal
            contentPanel?.hidesOnDeactivate = false
        }
        store?.isPanelPinned = isPanelPinned
    }

    private func applyPinState() {
        guard let panel = contentPanel else { return }
        panel.hidesOnDeactivate = false
        panel.level = isPanelPinned ? .floating : .normal
    }

    private func placeContentPanel() {
        guard let panel = contentPanel else { return }
        if let vals = UserDefaults.standard.array(forKey: Keys.contentFrame) as? [Double], vals.count == 4 {
            let frame = NSRect(x: vals[0], y: vals[1], width: vals[2], height: vals[3])
            if frame.width > 200, frame.height > 200,
               NSScreen.screens.contains(where: { $0.frame.intersects(frame) }) {
                panel.setFrame(frame, display: true)
                didPlaceContent = true
                return
            }
        }
        centerContentPanel()
        didPlaceContent = true
    }

    private func centerContentPanel() {
        guard let panel = contentPanel else { return }
        let size = NSSize(width: 380, height: 520)
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    private func persistContentFrame() {
        guard let panel = contentPanel else { return }
        let f = panel.frame
        UserDefaults.standard.set(
            [f.origin.x, f.origin.y, f.size.width, f.size.height],
            forKey: Keys.contentFrame
        )
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSPanel === contentPanel {
            persistContentFrame()
            store?.isPanelOpen = false
        }
    }

    func windowDidMove(_ notification: Notification) {
        if notification.object as? NSPanel === contentPanel {
            persistContentFrame()
        }
    }

    func windowDidResize(_ notification: Notification) {
        if notification.object as? NSPanel === contentPanel {
            persistContentFrame()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSPanel === contentPanel else { return }
        guard Date() >= ignoreResignUntil else { return }
        guard !isPanelPinned else { return }
        // Small delay: clicking pin/settings inside shouldn't close.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            guard Date() >= self.ignoreResignUntil else { return }
            guard !self.isPanelPinned else { return }
            guard self.contentPanel?.isKeyWindow != true else { return }
            self.hideContentPanel(force: false)
        }
    }
}
