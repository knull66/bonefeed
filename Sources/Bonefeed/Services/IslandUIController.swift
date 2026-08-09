import AppKit
import QuartzCore
import SwiftUI

/// Collapsed menu-bar strip, persistent P2P timer dock, or full peek card.
enum NotchDisplayMode: Equatable {
    case collapsed
    case p2pDock
    case expanded
}

/// Floating menu-bar notch + detachable content panel.
@MainActor
final class IslandUIController: NSObject, NSWindowDelegate {
    static let shared = IslandUIController()

    private weak var store: AppStore?
    private var notchPanel: NSPanel?
    private var contentPanel: NSPanel?
    private var screenObserver: NSObjectProtocol?
    private var didPlaceContent = false
    private var notchMode: NotchDisplayMode = .collapsed
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
        store.onNotchHoverExpand = { [weak self] expanded in
            // Legacy bool bridge — prefer dock when collapsing with a live P2P order.
            if expanded {
                self?.setNotchMode(.expanded)
            } else if self?.store?.snapshot.openP2POrders.first != nil {
                self?.setNotchMode(.p2pDock)
            } else {
                self?.setNotchMode(.collapsed)
            }
        }
        store.onNotchModeChange = { [weak self] mode in
            self?.setNotchMode(mode)
        }

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
                contentRect: NSRect(x: 0, y: 0, width: 260, height: 37),
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

    func setNotchExpanded(_ expanded: Bool) {
        setNotchMode(expanded ? .expanded : .collapsed)
    }

    func setNotchMode(_ mode: NotchDisplayMode) {
        if notchMode == mode {
            if mode != .collapsed { repositionNotch(animated: true) }
            return
        }
        notchMode = mode
        store?.notchHoverExpanded = mode == .expanded
        store?.notchDisplayMode = mode
        repositionNotch(animated: true)
    }

    func repositionNotch(animated: Bool = false) {
        guard let panel = notchPanel else { return }
        guard let screen = notchScreen() else { return }

        // Match the real menu-bar strip (often ~25–38pt), not a hard-coded 24.
        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, 25)
        store?.notchMenuBarHeight = menuBarHeight
        let collapsedHeight = menuBarHeight
        let height: CGFloat = {
            switch notchMode {
            case .collapsed: collapsedHeight
            case .p2pDock: menuBarHeight + 40
            case .expanded: max(168, menuBarHeight + 140)
            }
        }()
        let midX = screen.frame.midX
        var width: CGFloat = notchMode == .collapsed ? 320 : 360
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           right.minX > left.maxX + 40 {
            let gap = right.minX - left.maxX
            let minW: CGFloat = notchMode == .collapsed ? 200 : 260
            let pad: CGFloat = notchMode == .collapsed ? -8 : 48
            width = min(width, max(minW, gap + pad))
        }

        let x = midX - width / 2
        let y = screen.frame.maxY - height
        let frame = NSRect(x: x, y: y, width: width, height: height)

        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.40
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
                panel.animator().setFrame(frame, display: true)
            } completionHandler: { [weak panel] in
                Task { @MainActor in
                    panel?.contentView?.frame = NSRect(origin: .zero, size: frame.size)
                }
            }
        } else {
            panel.setFrame(frame, display: true)
            panel.contentView?.frame = NSRect(origin: .zero, size: frame.size)
        }
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
            hosting.sizingOptions = []
            // Normal Mac window chrome: transparent titlebar + real close traffic light.
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = hosting
            // Empty title — brand is drawn in the SwiftUI toolbar (avoids "Bonefeed" twice).
            panel.title = ""
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.titlebarSeparatorStyle = .none
            panel.toolbarStyle = .unifiedCompact
            panel.isOpaque = true
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.minSize = NSSize(width: 360, height: 480)
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.standardWindowButton(.closeButton)?.isHidden = false
            panel.hidesOnDeactivate = false
            contentPanel = panel
            applyPinState()
            placeContentPanel()
        }

        applyPanelBackground()

        // Splash each open.
        store.panelOpenToken &+= 1
        store.isPanelOpen = true

        guard let panel = contentPanel else { return }
        if !didPlaceContent {
            placeContentPanel()
        }
        // Ensure the system close light is visible and clickable.
        panel.standardWindowButton(.closeButton)?.isHidden = false
        panel.standardWindowButton(.closeButton)?.alphaValue = 1
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    /// Titlebar strip uses the theme background (not pure black).
    func syncPanelBackground() {
        applyPanelBackground()
    }

    private func applyPanelBackground() {
        guard let panel = contentPanel, let store else { return }
        panel.backgroundColor = NSColor(store.palette.bg)
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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === contentPanel else { return true }
        // Traffic-light close should always dismiss, even when pinned.
        hideContentPanel(force: true)
        return false
    }

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
