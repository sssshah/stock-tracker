import SwiftUI
import AppKit

@main
struct StockTickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 80)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .help) {}
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarExtra()
    }

    private func setupMenuBarExtra() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = makeMenuBarIcon()
        button.imagePosition = .imageLeft
        button.title = " Portfolio"
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)

        let menu = NSMenu()

        // About / Assumptions
        let aboutItem = NSMenuItem(title: "About & Data Assumptions…",
                                   action: #selector(openAbout),
                                   keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(.separator())

        let editItem = NSMenuItem(title: "Edit Portfolio…", action: #selector(openPortfolioEditor), keyEquivalent: ",")
        editItem.target = self
        menu.addItem(editItem)
        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Stock Ticker",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func makeMenuBarIcon() -> NSImage {
        let size = CGSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 1, y: 4))
            path.addLine(to: CGPoint(x: 5, y: 8))
            path.addLine(to: CGPoint(x: 9, y: 5))
            path.addLine(to: CGPoint(x: 15, y: 12))
            ctx.addPath(path)
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.setLineWidth(1.5); ctx.setLineCap(.round); ctx.setLineJoin(.round)
            ctx.strokePath()
            let arrow = CGMutablePath()
            arrow.move(to: CGPoint(x: 11, y: 12))
            arrow.addLine(to: CGPoint(x: 15, y: 12))
            arrow.addLine(to: CGPoint(x: 15, y: 8))
            ctx.addPath(arrow)
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.setLineWidth(1.5); ctx.setLineCap(.round)
            ctx.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func openAbout() {
        // Write the assumptions HTML to a temp file and open in browser
        let html = AssumptionsPage.html
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("StockTicker-Assumptions.html")
        try? html.write(to: tmpURL, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(tmpURL)
    }

    @objc private func openPortfolioEditor() {
        NotificationCenter.default.post(name: .openPortfolioEditor, object: nil)
    }
    @objc private func refreshNow() {
        NotificationCenter.default.post(name: .refreshTicker, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openPortfolioEditor = Notification.Name("openPortfolioEditor")
    static let refreshTicker       = Notification.Name("refreshTicker")
    static let windowDidMaximize   = Notification.Name("windowDidMaximize")
    static let windowDidRestore    = Notification.Name("windowDidRestore")
}

// MARK: - ESC-aware NSView

class EscapeResponderView: NSView {
    var onEscape: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}

// Stable key for associated object — must be a pointer, not a string literal
private var moveObserverKey: UInt8 = 0

// MARK: - Window Mouse Tracker
// Covers the full window. In maximized mode, hides the titlebar container
// and reveals it only when cursor enters the top-left hover zone.

class WindowMouseTracker: NSView {
    weak var trackedWindow: NSWindow?
    var isWindowMaximized = false
    private var trackingArea: NSTrackingArea?

    // Never intercept clicks — return nil so AppKit routes them to views below
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }

    // Hot zone: top-left 80×full-height — user just needs to be near the left edge
    private let hotZoneWidth: CGFloat = 80

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea { removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        guard isWindowMaximized else { return }
        let loc = convert(event.locationInWindow, from: nil)
        setTitlebar(visible: loc.x < hotZoneWidth)
    }

    override func mouseExited(with event: NSEvent) {
        guard isWindowMaximized else { return }
        setTitlebar(visible: false)
    }

    // Find the titlebar container view by walking the view hierarchy
    private func titlebarContainer(in window: NSWindow) -> NSView? {
        // The titlebar lives in the window's contentView superview (_NSThemeFrame)
        // We look for the view that contains the close button
        guard let closeButton = window.standardWindowButton(.closeButton) else { return nil }
        return closeButton.superview
    }

    func setTitlebar(visible: Bool) {
        guard let window = trackedWindow ?? self.window else { return }
        let alpha: CGFloat = visible ? 1 : 0
        guard let container = titlebarContainer(in: window) else {
            // Fallback: just animate the buttons themselves
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
                    window.standardWindowButton(type)?.animator().alphaValue = alpha
                }
            }
            return
        }
        let current = container.alphaValue
        guard abs(current - alpha) > 0.01 else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            container.animator().alphaValue = alpha
        }
    }

    func hideTitlebarNow() {
        guard let window = trackedWindow ?? self.window,
              let container = titlebarContainer(in: window) else { return }
        container.alphaValue = 0
    }

    func showTitlebarNow() {
        guard let window = trackedWindow ?? self.window,
              let container = titlebarContainer(in: window) else { return }
        container.alphaValue = 1
    }
}

// MARK: - Window Accessor

struct WindowAccessor: NSViewRepresentable {

    func makeNSView(context: Context) -> EscapeResponderView {
        let view = EscapeResponderView()
        view.onEscape = { [weak coordinator = context.coordinator] in
            coordinator?.restoreIfMaximized()
        }

        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.makeFirstResponder(view)
            window.level = .floating
            window.isMovableByWindowBackground = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            // Fully transparent window — no background at all
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false

            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.styleMask.insert(.resizable)
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.cornerRadius = 10
            window.contentView?.layer?.masksToBounds = true
            window.contentView?.layer?.backgroundColor = .clear

            // Wire green zoom button
            if let zoomButton = window.standardWindowButton(.zoomButton) {
                zoomButton.target = context.coordinator
                zoomButton.action = #selector(Coordinator.handleZoom(_:))
                context.coordinator.window = window
                context.coordinator.responderView = view
            }

            // Install mouse tracker on the window's frame view (outside SwiftUI's
            // managed NSHostingController.view hierarchy) to avoid the subview warning.
            // We use the contentView's superview (_NSThemeFrame) which wraps everything.
            let hostView = window.contentView?.superview ?? window.contentView
            guard let hostView = hostView else { return }
            let tracker = WindowMouseTracker(frame: hostView.bounds)
            tracker.autoresizingMask = [.width, .height]
            tracker.trackedWindow = window
            hostView.addSubview(tracker, positioned: .above, relativeTo: nil)
            context.coordinator.mouseTracker = tracker

            // Option D: restore last saved position, start observing moves
            context.coordinator.restoreSavedPosition()
            let observer = WindowMoveObserver(window: window,
                                              coordinator: context.coordinator)
            // Retain observer for window lifetime via associated object
            objc_setAssociatedObject(window, &moveObserverKey, observer,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return view
    }

    func updateNSView(_ nsView: EscapeResponderView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        weak var window: NSWindow?
        weak var responderView: EscapeResponderView?
        weak var mouseTracker: WindowMouseTracker?
        var isMaximized = false
        var normalFrame: NSRect = .zero

        // UserDefaults key for persisting window position (Option D)
        private let positionKey = "ticker_window_frame"

        // Called once after window is set up — restore saved position
        func restoreSavedPosition() {
            guard let window = window,
                  let saved = UserDefaults.standard.string(forKey: positionKey) else { return }
            let frame = NSRectFromString(saved)
            guard frame != .zero else { return }
            // Validate it's still on screen
            if let screen = window.screen, screen.visibleFrame.intersects(frame) {
                window.setFrameOrigin(frame.origin)
            }
        }

        // Save current position to UserDefaults
        func savePosition() {
            guard let window = window else { return }
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: positionKey)
        }

        @objc func handleZoom(_ sender: Any?) {
            guard let window = window, let screen = window.screen else { return }
            if isMaximized {
                restoreIfMaximized()
            } else {
                // Option D: save position before maximizing
                normalFrame = window.frame
                savePosition()

                let screenFrame = screen.visibleFrame
                let fullFrame   = screen.frame   // includes menu bar area

                // Snap flush to bottom of macOS menu bar.
                // We use screen.frame.maxY (top of screen) minus the window
                // height so the content edge sits right at the menu bar bottom.
                // visibleFrame.maxY would leave a gap equal to the titlebar height.
                let newFrame = NSRect(
                    x: screenFrame.minX,
                    y: fullFrame.maxY - window.frame.height,
                    width: screenFrame.width,
                    height: window.frame.height
                )
                window.setFrame(newFrame, display: true, animate: true)
                isMaximized = true
                window.makeFirstResponder(responderView)

                mouseTracker?.isWindowMaximized = true
                mouseTracker?.hideTitlebarNow()

                NotificationCenter.default.post(name: .windowDidMaximize,
                                                object: screenFrame.width)
            }
        }

        func restoreIfMaximized() {
            guard isMaximized, let window = window else { return }
            mouseTracker?.isWindowMaximized = false
            mouseTracker?.showTitlebarNow()

            // Restore to saved pre-maximize position
            window.setFrame(normalFrame, display: true, animate: true)
            isMaximized = false
            NotificationCenter.default.post(name: .windowDidRestore, object: nil)
        }
    }
}

// MARK: - Window Move Observer
// Saves position to UserDefaults whenever the window is dragged.

class WindowMoveObserver: NSObject {
    private weak var window: NSWindow?
    private weak var coordinator: WindowAccessor.Coordinator?
    private let positionKey = "ticker_window_frame"

    init(window: NSWindow, coordinator: WindowAccessor.Coordinator) {
        self.window = window
        self.coordinator = coordinator
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowMoved),
            name: NSWindow.didMoveNotification,
            object: window
        )
    }

    @objc private func windowMoved() {
        guard let window = window else { return }
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: positionKey)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
