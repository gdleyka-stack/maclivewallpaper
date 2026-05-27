import AppKit
import Foundation
import QuartzCore
import UniformTypeIdentifiers
import AVFoundation

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

// Premium Capsule Segmented Control
class CustomSegmentedControl: NSView {
    var segmentChangedHandler: ((Int) -> Void)?
    private var selectedIndex: Int = 0
    
    private let selectionIndicator = NSView()
    private let button1 = NSButton()
    private let button2 = NSButton()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 17
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
        
        // Selection Indicator (sliding background capsule)
        selectionIndicator.wantsLayer = true
        selectionIndicator.layer?.cornerRadius = 14
        selectionIndicator.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
        addSubview(selectionIndicator)
        
        // Buttons
        setupButton(button1, title: "Settings", index: 0)
        setupButton(button2, title: "Gallery", index: 1)
        
        updateSelection(animated: false)
    }
    
    private func setupButton(_ button: NSButton, title: String, index: Int) {
        button.isBordered = false
        button.title = ""
        button.wantsLayer = true
        
        button.target = self
        button.action = #selector(buttonClicked(_:))
        button.tag = index
        addSubview(button)
    }
    
    override func layout() {
        super.layout()
        let btnWidth = bounds.width / 2
        button1.frame = NSRect(x: 0, y: 0, width: btnWidth, height: bounds.height)
        button2.frame = NSRect(x: btnWidth, y: 0, width: btnWidth, height: bounds.height)
        updateSelection(animated: false)
    }
    
    @objc private func buttonClicked(_ sender: NSButton) {
        let index = sender.tag
        if index != selectedIndex {
            selectedIndex = index
            updateSelection(animated: true)
            segmentChangedHandler?(selectedIndex)
        }
    }
    
    private func updateSelection(animated: Bool) {
        let btnWidth = bounds.width / 2
        let indicatorFrame = NSRect(x: CGFloat(selectedIndex) * btnWidth + 3, y: 3, width: btnWidth - 6, height: bounds.height - 6)
        
        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = .center
        
        let activeAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .paragraphStyle: pstyle
        ]
        let inactiveAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .paragraphStyle: pstyle
        ]
        
        button1.attributedTitle = NSAttributedString(string: "Settings", attributes: selectedIndex == 0 ? activeAttrs : inactiveAttrs)
        button2.attributedTitle = NSAttributedString(string: "Gallery", attributes: selectedIndex == 1 ? activeAttrs : inactiveAttrs)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                selectionIndicator.animator().frame = indicatorFrame
            }
        } else {
            selectionIndicator.frame = indicatorFrame
        }
    }
}

// Empty placeholder view for Settings
class SettingsView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// Minimalist, borderless white button with subtle border on hover for adding videos
class MinimalAddButton: NSButton {
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
        self.layer?.cornerRadius = 8
        self.layer?.borderWidth = 1.0
        self.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        self.layer?.backgroundColor = NSColor.clear.cgColor
        
        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = .center
        self.attributedTitle = NSAttributedString(string: "+ Add Video", attributes: [
            .foregroundColor: NSColor.white.withAlphaComponent(0.75),
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
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
        self.layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        self.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        
        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = .center
        self.attributedTitle = NSAttributedString(string: "+ Add Video", attributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .paragraphStyle: pstyle
        ])
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSCursor.arrow.set()
        self.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        self.layer?.backgroundColor = NSColor.clear.cgColor
        
        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = .center
        self.attributedTitle = NSAttributedString(string: "+ Add Video", attributes: [
            .foregroundColor: NSColor.white.withAlphaComponent(0.75),
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .paragraphStyle: pstyle
        ])
    }
}

// Scrollable Gallery with an Add Video button at the bottom and max 2 cells per row
class GalleryView: NSView {
    private let scrollView = NSScrollView()
    private let documentView = NSView()
    private let addButton = MinimalAddButton()
    
    struct GalleryItem {
        let title: String
        let colors: [NSColor]
        let videoURL: URL?
        let thumbnail: NSImage?
    }
    
    private var items: [GalleryItem] = []
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // 1. Add Video Button
        addButton.frame = NSRect(x: (bounds.width - 110) / 2, y: 8, width: 110, height: 26)
        addButton.target = self
        addButton.action = #selector(addVideoClicked)
        addSubview(addButton)
        
        // 2. Scroll View
        scrollView.frame = NSRect(x: 0, y: 42, width: bounds.width, height: bounds.height - 42)
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = documentView
        
        addSubview(scrollView)
        
        layoutGallery()
    }
    
    private func generateThumbnail(for url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        do {
            let imageRef = try generator.copyCGImage(at: time, actualTime: nil)
            return NSImage(cgImage: imageRef, size: NSZeroSize)
        } catch {
            do {
                let imageRef = try generator.copyCGImage(at: .zero, actualTime: nil)
                return NSImage(cgImage: imageRef, size: NSZeroSize)
            } catch {
                return nil
            }
        }
    }
    
    @objc private func addVideoClicked() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Video File"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        // Force the app to become active so the file dialog gets focus and comes to front
        NSApp.activate(ignoringOtherApps: true)
        
        let response = openPanel.runModal()
        if response == .OK, let url = openPanel.url {
            let filename = url.lastPathComponent
            let colors: [NSColor] = [
                NSColor(red: CGFloat.random(in: 0.2...0.8), green: CGFloat.random(in: 0.2...0.8), blue: CGFloat.random(in: 0.2...0.8), alpha: 1.0),
                NSColor(red: CGFloat.random(in: 0.2...0.8), green: CGFloat.random(in: 0.2...0.8), blue: CGFloat.random(in: 0.2...0.8), alpha: 1.0)
            ]
            let thumbnail = generateThumbnail(for: url)
            let newItem = GalleryItem(title: filename, colors: colors, videoURL: url, thumbnail: thumbnail)
            self.items.append(newItem)
            self.layoutGallery()
        }
    }
    
    private func layoutGallery() {
        documentView.subviews.forEach { $0.removeFromSuperview() }
        
        let availableWidth = scrollView.contentSize.width
        let cardWidth: CGFloat = 110
        let cardHeight: CGFloat = 90
        let gap: CGFloat = 12
        let columnsCount = 2
        
        let totalItems = items.count
        let rowsCount = Int(ceil(Double(totalItems) / Double(columnsCount)))
        
        let contentHeight = max(scrollView.contentSize.height, CGFloat(rowsCount) * (cardHeight + gap) + gap)
        documentView.frame = NSRect(x: 0, y: 0, width: availableWidth, height: contentHeight)
        
        for i in 0..<totalItems {
            let col = i % columnsCount
            let row = i / columnsCount
            
            let leftOffset = (availableWidth - (CGFloat(columnsCount) * cardWidth + CGFloat(columnsCount - 1) * gap)) / 2
            let x = leftOffset + CGFloat(col) * (cardWidth + gap)
            let y = contentHeight - cardHeight - gap - CGFloat(row) * (cardHeight + gap)
            
            let card = NSView(frame: NSRect(x: x, y: y, width: cardWidth, height: cardHeight))
            card.wantsLayer = true
            card.layer?.cornerRadius = 10
            card.layer?.masksToBounds = true
            
            if let thumbnail = items[i].thumbnail,
               let cgImage = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                card.layer?.contents = cgImage
                card.layer?.contentsGravity = .resizeAspectFill
            } else {
                let gradient = CAGradientLayer()
                gradient.frame = card.bounds
                gradient.colors = items[i].colors.map { $0.cgColor }
                gradient.startPoint = CGPoint(x: 0, y: 0)
                gradient.endPoint = CGPoint(x: 1, y: 1)
                card.layer?.addSublayer(gradient)
            }
            
            let textBg = NSView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: 34))
            textBg.wantsLayer = true
            textBg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
            
            let label = NSTextField(labelWithString: items[i].title)
            label.font = NSFont.systemFont(ofSize: 10, weight: .bold)
            label.textColor = .white
            label.alignment = .center
            label.lineBreakMode = .byTruncatingMiddle
            label.cell?.wraps = true
            label.cell?.isScrollable = false
            label.frame = NSRect(x: 4, y: 4, width: cardWidth - 8, height: 26)
            textBg.addSubview(label)
            
            card.addSubview(textBg)
            documentView.addSubview(card)
        }
        
        if contentHeight > scrollView.contentSize.height {
            documentView.scroll(NSPoint(x: 0, y: contentHeight - scrollView.contentSize.height))
        }
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
        self.isMovableByWindowBackground = false
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
    
    var contentContainer: NSView?
    var settingsView: SettingsView?
    var galleryView: GalleryView?
    
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
        
        // Custom Capsule Segmented Control (Tabs)
        let segment = CustomSegmentedControl(frame: NSRect(x: 20, y: windowHeight - 60, width: windowWidth - 40, height: 34))
        segment.segmentChangedHandler = { [weak self] index in
            self?.segmentChanged(index)
        }
        visualEffect.addSubview(segment)
        
        // Content Container
        let container = NSView(frame: NSRect(x: 20, y: 75, width: windowWidth - 40, height: windowHeight - 60 - 75 - 10))
        visualEffect.addSubview(container)
        self.contentContainer = container
        
        // Add Subviews
        let settings = SettingsView(frame: container.bounds)
        let gallery = GalleryView(frame: container.bounds)
        gallery.isHidden = true
        
        container.addSubview(settings)
        container.addSubview(gallery)
        
        self.settingsView = settings
        self.galleryView = gallery
        
        // Red Quit Button
        let quitButton = RedQuitButton(frame: NSRect(x: 20, y: 20, width: windowWidth - 40, height: 40))
        quitButton.target = self
        quitButton.action = #selector(quitClicked(_:))
        visualEffect.addSubview(quitButton)
        
        self.window = panel
    }
    
    func segmentChanged(_ index: Int) {
        if index == 0 {
            settingsView?.isHidden = false
            galleryView?.isHidden = true
        } else {
            settingsView?.isHidden = true
            galleryView?.isHidden = false
        }
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
