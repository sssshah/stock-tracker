import SwiftUI
import AppKit

@main
struct StockTickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene — window is created entirely by AppDelegate using NSPanel
        Settings { EmptyView() }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var panel: NSPanel?
    var coordinator: WindowCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarExtra()
        setupPanel()
    }

    // MARK: - NSPanel Setup

    private func setupPanel() {
        let width: CGFloat = 1200
        let height: CGFloat = 80

        // Position at top-center of main screen by default
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true

        // TickerViewModel is @MainActor — create it on the main actor
        Task { @MainActor in
            let viewModel = TickerViewModel()
            let contentView = ContentView(viewModel: viewModel)
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)

            panel.contentView = hostingView
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.cornerRadius = 10
            panel.contentView?.layer?.masksToBounds = true

            // Restore saved position
            if let saved = UserDefaults.standard.string(forKey: "ticker_window_frame") {
                let frame = NSRectFromString(saved)
                let screen = NSScreen.main ?? NSScreen.screens[0]
                if frame != .zero, screen.frame.intersects(frame) {
                    panel.setFrameOrigin(frame.origin)
                }
            }

            let coord = WindowCoordinator(panel: panel)
            self.coordinator = coord

            panel.makeKeyAndOrderFront(nil)
            self.panel = panel
        }
    }

    // MARK: - Menu Bar Extra

    private func setupMenuBarExtra() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = makeMenuBarIcon()
        button.imagePosition = .imageLeft
        button.title = " Portfolio"
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)

        let menu = NSMenu()

        let aboutItem = NSMenuItem(title: "About & Data Assumptions…",
                                   action: #selector(openAbout),
                                   keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(.separator())

        let editItem = NSMenuItem(title: "Edit Portfolio…",
                                  action: #selector(openPortfolioEditor),
                                  keyEquivalent: ",")
        editItem.target = self
        menu.addItem(editItem)
        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Refresh Now",
                                     action: #selector(refreshNow),
                                     keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Stock Ticker Streamer",
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
    static let toggleMaximize      = Notification.Name("toggleMaximize")
}

// MARK: - Window Coordinator
// Handles maximize/restore, position persistence, and ESC key for the NSPanel.

class WindowCoordinator: NSObject {
    weak var panel: NSPanel?
    var isMaximized = false
    var normalFrame: NSRect = .zero
    private let positionKey = "ticker_window_frame"
    private var monitor: Any?

    init(panel: NSPanel) {
        self.panel = panel
        super.init()

        // Save position on move
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelMoved),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        // Listen for maximize toggle from ContentView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleMaximize),
            name: .toggleMaximize,
            object: nil
        )

        // ESC key via local monitor
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.restoreIfMaximized()
                return nil
            }
            return event
        }
    }

    @objc private func handleToggleMaximize() {
        if isMaximized { restoreIfMaximized() } else { maximize() }
    }

    @objc private func panelMoved() {
        guard let panel = panel, !isMaximized else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: positionKey)
    }

    func maximize() {
        guard let panel = panel, let screen = panel.screen else { return }
        normalFrame = panel.frame
        UserDefaults.standard.set(NSStringFromRect(normalFrame), forKey: positionKey)

        let screenFrame = screen.visibleFrame
        let fullFrame = screen.frame
        let newFrame = NSRect(
            x: screenFrame.minX,
            y: fullFrame.maxY - panel.frame.height,
            width: screenFrame.width,
            height: panel.frame.height
        )
        panel.setFrame(newFrame, display: true, animate: true)
        isMaximized = true
        NotificationCenter.default.post(name: .windowDidMaximize, object: screenFrame.width)
    }

    func restoreIfMaximized() {
        guard isMaximized, let panel = panel else { return }
        panel.setFrame(normalFrame, display: true, animate: true)
        isMaximized = false
        NotificationCenter.default.post(name: .windowDidRestore, object: nil)
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Window Move Observer (kept for compatibility)

class WindowMoveObserver: NSObject {
    private weak var window: NSWindow?
    private let positionKey = "ticker_window_frame"

    init(window: NSWindow, coordinator: AnyObject) {
        self.window = window
        super.init()
    }
}

private var moveObserverKey: UInt8 = 0
