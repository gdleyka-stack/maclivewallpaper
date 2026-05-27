import AppKit
import Foundation

// Custom vector drawing for the tray status item (Player play button)
func createTrayIcon() -> NSImage {
    if let symbolImage = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil) {
        return symbolImage
    }
    
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
        let path = NSBezierPath()
        // Triangle pointing to the right
        path.move(to: NSPoint(x: 6, y: 4))
        path.line(to: NSPoint(x: 14, y: 9))
        path.line(to: NSPoint(x: 6, y: 14))
        path.close()
        
        NSColor.black.setFill()
        path.fill()
        
        return true
    }
    image.isTemplate = true
    return image
}

// Custom button with hover effect and white text (Quit Button)
class RedQuitButton: NSButton {
    private var trackingArea: NSTrackingArea?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        self.isBordered = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 10
        self.layer?.backgroundColor = NSColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 0.9).cgColor
        
        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = .center
        self.attributedTitle = NSAttributedString(string: "Quit Application", attributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .paragraphStyle: pstyle
        ])
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSCursor.pointingHand.set()
        self.layer?.backgroundColor = NSColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1.0).cgColor
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSCursor.arrow.set()
        self.layer?.backgroundColor = NSColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 0.9).cgColor
    }
}

// Custom panel acting as a floating popup window
class MainWindow: NSPanel, NSWindowDelegate {
    var lastResignTime: TimeInterval = 0
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.isReleasedWhenClosed = false
        self.delegate = self
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.hasShadow = true
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    func windowDidResignKey(_ notification: Notification) {
        lastResignTime = ProcessInfo.processInfo.systemUptime
        self.orderOut(nil)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var window: MainWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item (tray)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = createTrayIcon()
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
        }
        
        setupWindow()
        
        // Ensure it runs as a foreground app showing in Dock
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Position window near tray initially
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showWindowNearTray()
        }
    }
    
    func setupWindow() {
        let windowWidth: CGFloat = 300
        let windowHeight: CGFloat = 380
        
        let panel = MainWindow(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        
        // Vibrancy (frosted glass) background
        let visualEffect = NSVisualEffectView(frame: panel.contentView!.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.state = .active
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        panel.contentView?.addSubview(visualEffect)
        
        // Red Quit Button
        let quitButton = RedQuitButton(frame: NSRect(x: 20, y: 20, width: windowWidth - 40, height: 40))
        quitButton.target = self
        quitButton.action = #selector(quitClicked(_:))
        visualEffect.addSubview(quitButton)
        
        self.window = panel
    }
    
    @objc func statusBarButtonClicked(_ sender: AnyObject?) {
        toggleWindow()
    }
    
    @objc func quitClicked(_ sender: AnyObject?) {
        NSApp.terminate(nil)
    }
    
    func toggleWindow() {
        guard let window = self.window else { return }
        
        let now = ProcessInfo.processInfo.systemUptime
        // Avoid reopening immediately if it was closed via loss of focus
        if now - window.lastResignTime < 0.25 {
            return
        }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showWindowNearTray()
        }
    }
    
    // Position the window exactly below the tray icon
    func showWindowNearTray() {
        guard let window = self.window else { return }
        
        if let statusButton = statusItem?.button, let windowFrame = statusButton.window?.frame {
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
            let buttonOrigin = windowFrame.origin
            
            // If the status item is not yet positioned in the menu bar at the top of the screen,
            // retry after a small delay instead of showing it in the wrong place.
            if buttonOrigin.y < screenFrame.maxY - 120 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.showWindowNearTray()
                }
                return
            }
            
            var x = buttonOrigin.x + (windowFrame.width / 2) - (window.frame.width / 2)
            var y = buttonOrigin.y - window.frame.height - 5
            
            // Keep window on-screen bounds
            if x + window.frame.width > screenFrame.maxX {
                x = screenFrame.maxX - window.frame.width - 10
            }
            if x < screenFrame.minX {
                x = screenFrame.minX + 10
            }
            if y < screenFrame.minY {
                y = screenFrame.minY + 10
            }
            
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // Handle Dock icon click: always show near the tray icon
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let window = self.window else { return true }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showWindowNearTray()
        }
        return true
    }
}

// App entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
