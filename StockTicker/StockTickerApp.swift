import SwiftUI
import AppKit
import WebKit

@main
struct StockTickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene — window is created entirely by AppDelegate using NSPanel.
        // CommandGroup replacement suppresses the system ⌘, Settings window.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) { }
            }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var panel: FloatingPanel?
    var editorPanel: FloatingPanel?
    var aboutPanel: NSPanel?
    var newsPanel: NSPanel?
    var newsWebView: WKWebView?   // strong ref so WKNavigationDelegate isn't released
    var newsFallbackURL: URL?
    var coordinator: WindowCoordinator?
    var viewModel: TickerViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarExtra()
        setupPanel()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openNewsArticle(_:)),
            name: .newsArticleTapped,
            object: nil
        )
    }

    // MARK: - NSPanel Setup

    private func setupPanel() {
        let width: CGFloat = 1200
        let height: CGFloat = 80

        // Position at top-center of main screen by default
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height

        let panel = FloatingPanel(
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
        panel.appearance = NSAppearance(named: .darkAqua)

        // TickerViewModel is @MainActor — create it on the main actor
        Task { @MainActor in
            let viewModel = TickerViewModel()
            self.viewModel = viewModel
            let contentView = ContentView(viewModel: viewModel)
            let hostingView = FirstMouseHostingView(rootView: contentView)
            hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)

            panel.contentView = hostingView
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.cornerRadius = 10
            panel.contentView?.layer?.masksToBounds = true

            // Restore saved position
            if let saved = UserDefaults.standard.string(forKey: "ticker_window_frame"),
               let restoreScreen = NSScreen.main ?? NSScreen.screens.first {
                let frame = NSRectFromString(saved)
                if frame != .zero, restoreScreen.frame.intersects(frame) {
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
                                  keyEquivalent: "")
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

    @objc private func openNewsArticle(_ notification: Notification) {
        guard let info = notification.object as? [String: String],
              let urlString = info["url"],
              let url = URL(string: urlString) else { return }
        let headline = info["headline"] ?? "Article"

        newsPanel?.close()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        panel.title = headline
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)

        let webView = WKWebView()
        webView.navigationDelegate = self
        newsFallbackURL = url
        newsWebView = webView
        webView.load(URLRequest(url: url))
        panel.contentView = webView

        panel.center()
        panel.orderFrontRegardless()
        newsPanel = panel
    }

    @objc private func openAbout() {
        if let existing = aboutPanel, existing.isVisible {
            existing.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Data & Assumptions"
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = NSHostingView(rootView: AboutView())
        panel.center()
        panel.orderFrontRegardless()
        aboutPanel = panel
    }

    @objc private func openPortfolioEditor() {
        // If already open, just bring it forward
        if let existing = editorPanel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        guard let vm = viewModel else { return }

        let editorView = PortfolioEditorView(vm: vm, onDismiss: { [weak self] in
            self?.editorPanel?.close()
            self?.editorPanel = nil
        })

        let ep = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 500),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        ep.level = .floating
        ep.hidesOnDeactivate = false
        ep.backgroundColor = .clear
        ep.isOpaque = false
        ep.hasShadow = true
        ep.appearance = NSAppearance(named: .darkAqua)
        ep.contentView = FirstMouseHostingView(rootView: editorView)

        // Position below the ticker bar, horizontally centered on it
        if let tf = panel?.frame,
           let screen = NSScreen.main ?? NSScreen.screens.first {
            let x = tf.midX - 170
            let y = tf.minY - 510
            ep.setFrameOrigin(NSPoint(
                x: max(screen.visibleFrame.minX, min(x, screen.visibleFrame.maxX - 340)),
                y: max(screen.visibleFrame.minY, y)
            ))
        } else {
            ep.center()
        }

        ep.makeKeyAndOrderFront(nil)
        editorPanel = ep
    }

    @objc private func refreshNow() {
        NotificationCenter.default.post(name: .refreshTicker, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newsArticleTapped   = Notification.Name("newsArticleTapped")
    static let refreshTicker       = Notification.Name("refreshTicker")
    static let windowDidMaximize   = Notification.Name("windowDidMaximize")
    static let windowDidRestore    = Notification.Name("windowDidRestore")
    static let toggleMaximize      = Notification.Name("toggleMaximize")
}

// MARK: - Window Coordinator
// Handles maximize/restore, position persistence, and ESC key for the NSPanel.

class WindowCoordinator: NSObject {
    weak var panel: FloatingPanel?
    var isMaximized = false
    var normalFrame: NSRect = .zero
    private let positionKey = "ticker_window_frame"
    private var monitor: Any?

    init(panel: FloatingPanel) {
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

// MARK: - FloatingPanel
// canBecomeKey = true is required for both the ticker bar (so tap gestures and
// hover controls receive events) and the editor (so TextFields can become first
// responder). nonactivatingPanel prevents the app from stealing focus from other
// apps — that is what keeps the panel unobtrusive, not canBecomeKey.

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// Forwards the first mouse-down to SwiftUI even when the panel is becoming key,
// so tap gestures fire on the first click instead of the second.
class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - WKNavigationDelegate
// Falls back to the default browser if the in-app WKWebView can't load the page
// (e.g. ATS blocks an HTTP URL, or the server is unreachable).

extension AppDelegate: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        openInBrowser()
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        openInBrowser()
    }

    private func openInBrowser() {
        guard let url = newsFallbackURL else { return }
        newsPanel?.close()
        newsPanel = nil
        NSWorkspace.shared.open(url)
    }
}

