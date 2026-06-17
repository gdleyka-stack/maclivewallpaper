import AppKit
import Foundation


func createTrayIcon() -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
        let screenRect = NSRect(x: 1.5, y: 4.5, width: 15, height: 10.5)
        let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 1.5, yRadius: 1.5)
        screenPath.lineWidth = 1.5
        
        let standPath = NSBezierPath()
        standPath.move(to: NSPoint(x: 9, y: 4.5))
        standPath.line(to: NSPoint(x: 9, y: 1.5))
        standPath.move(to: NSPoint(x: 5, y: 1.5))
        standPath.line(to: NSPoint(x: 13, y: 1.5))
        standPath.lineWidth = 1.5
        
        NSColor.black.setStroke()
        screenPath.stroke()
        standPath.stroke()
        
        let dotRect = NSRect(x: 7.5, y: 8.5, width: 3, height: 3)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        NSColor.black.setFill()
        dotPath.fill()
        
        return true
    }
    image.isTemplate = true 
    return image
}


func createLargeIcon() -> NSImage {
    let size = NSSize(width: 80, height: 80)
    let image = NSImage(size: size, flipped: false) { rect in
        
        let bgPath = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
        NSColor.systemBlue.withAlphaComponent(0.12).setFill()
        bgPath.fill()
        
        
        let monitorWidth: CGFloat = 52
        let monitorHeight: CGFloat = 36
        let monitorRect = NSRect(
            x: (size.width - monitorWidth) / 2,
            y: (size.height - monitorHeight) / 2 + 6,
            width: monitorWidth,
            height: monitorHeight
        )
        let screenPath = NSBezierPath(roundedRect: monitorRect, xRadius: 4, yRadius: 4)
        NSColor.systemBlue.setStroke()
        screenPath.lineWidth = 2.5
        screenPath.stroke()
        
        
        let standPath = NSBezierPath()
        standPath.move(to: NSPoint(x: size.width / 2, y: monitorRect.minY))
        standPath.line(to: NSPoint(x: size.width / 2, y: monitorRect.minY - 8))
        standPath.move(to: NSPoint(x: size.width / 2 - 12, y: monitorRect.minY - 8))
        standPath.line(to: NSPoint(x: size.width / 2 + 12, y: monitorRect.minY - 8))
        standPath.lineWidth = 2.5
        standPath.lineCapStyle = .round
        standPath.stroke()
        
        
        let clipPath = NSBezierPath(roundedRect: monitorRect.insetBy(dx: 2, dy: 2), xRadius: 2, yRadius: 2)
        NSGraphicsContext.current?.saveGraphicsState()
        clipPath.addClip()
        
        
        let sunPath = NSBezierPath(ovalIn: NSRect(x: monitorRect.minX + 30, y: monitorRect.minY + 18, width: 10, height: 10))
        NSColor.systemOrange.withAlphaComponent(0.85).setFill()
        sunPath.fill()
        
        
        let mountainPath = NSBezierPath()
        mountainPath.move(to: NSPoint(x: monitorRect.minX, y: monitorRect.minY))
        mountainPath.line(to: NSPoint(x: monitorRect.minX + 16, y: monitorRect.minY + 16))
        mountainPath.line(to: NSPoint(x: monitorRect.minX + 32, y: monitorRect.minY + 6))
        mountainPath.line(to: NSPoint(x: monitorRect.minX + 44, y: monitorRect.minY + 18))
        mountainPath.line(to: NSPoint(x: monitorRect.maxX, y: monitorRect.minY))
        mountainPath.close()
        
        NSColor.systemBlue.withAlphaComponent(0.6).setFill()
        mountainPath.fill()
        
        NSGraphicsContext.current?.restoreGraphicsState()
        
        return true
    }
    return image
}


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
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = createTrayIcon()
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
        }
        
        setupWindow()
        
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        
        showWindowNearTray()
    }
    
    func setupWindow() {
        let windowWidth: CGFloat = 300
        let windowHeight: CGFloat = 380
        
        let panel = MainWindow(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        
        
        let visualEffect = NSVisualEffectView(frame: panel.contentView!.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.state = .active
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        panel.contentView?.addSubview(visualEffect)
        
        
        let imageView = NSImageView(frame: NSRect(x: (windowWidth - 80) / 2, y: windowHeight - 95, width: 80, height: 80))
        imageView.image = createLargeIcon()
        visualEffect.addSubview(imageView)
        
        
        let titleLabel = NSTextField(labelWithString: "Live Wallpaper")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: windowHeight - 122, width: windowWidth - 40, height: 25)
        visualEffect.addSubview(titleLabel)
        
        
        let subtitleLabel = NSTextField(labelWithString: "macOS Control Utility")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: windowHeight - 140, width: windowWidth - 40, height: 18)
        visualEffect.addSubview(subtitleLabel)
        
        
        let box = NSView(frame: NSRect(x: 20, y: 80, width: windowWidth - 40, height: windowHeight - 235))
        box.wantsLayer = true
        box.layer?.cornerRadius = 12
        box.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor
        visualEffect.addSubview(box)
        
        
        let statusTitle = NSTextField(labelWithString: "STATUS")
        statusTitle.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        statusTitle.textColor = .secondaryLabelColor
        statusTitle.alignment = .center
        statusTitle.frame = NSRect(x: 0, y: box.bounds.height - 25, width: box.bounds.width, height: 15)
        box.addSubview(statusTitle)
        
        let statusText = NSTextField(labelWithString: "Running in Dock & Menu Bar")
        statusText.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusText.textColor = .labelColor
        statusText.alignment = .center
        statusText.frame = NSRect(x: 10, y: box.bounds.height / 2 - 10, width: box.bounds.width - 20, height: 20)
        box.addSubview(statusText)
        
        let subText = NSTextField(labelWithString: "Click icons to toggle window")
        subText.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subText.textColor = .secondaryLabelColor
        subText.alignment = .center
        subText.frame = NSRect(x: 10, y: box.bounds.height / 2 - 30, width: box.bounds.width - 20, height: 20)
        box.addSubview(subText)
        
        
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
        
        if now - window.lastResignTime < 0.25 {
            return
        }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showWindowNearTray()
        }
    }
    
    
    func showWindowNearTray() {
        guard let window = self.window else { return }
        
        if let statusButton = statusItem?.button, let windowFrame = statusButton.window?.frame {
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
            let buttonOrigin = windowFrame.origin
            
            var x = buttonOrigin.x + (windowFrame.width / 2) - (window.frame.width / 2)
            var y = buttonOrigin.y - window.frame.height - 5
            
            
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


let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
