import AppKit
import Foundation
import QuartzCore
import AVFoundation

extension NSImage {
    func croppedToSquare() -> NSImage? {
        let size = self.size
        let side = min(size.width, size.height)
        if side <= 0 { return nil }
        
        let x = (size.width - side) / 2
        let y = (size.height - side) / 2
        let cropRect = NSRect(x: x, y: y, width: side, height: side)
        
        let croppedImage = NSImage(size: NSSize(width: side, height: side))
        croppedImage.lockFocus()
        self.draw(in: NSRect(x: 0, y: 0, width: side, height: side),
                  from: cropRect,
                  operation: .copy,
                  fraction: 1.0)
        croppedImage.unlockFocus()
        
        return croppedImage
    }
}

// MARK: - Persistence

struct GalleryStore {
    static let itemsKey = "gallery.items"
    static let activeURLKey = "gallery.activeURL"

    static func saveItems(_ items: [GalleryView.GalleryItem]) {
        let bookmarks = items.compactMap { item -> Data? in
            guard let url = item.videoURL else { return nil }
            return try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: itemsKey)
    }

    static func loadItems() -> [URL] {
        guard let bookmarks = UserDefaults.standard.array(forKey: itemsKey) as? [Data] else { return [] }
        var isStale = false
        return bookmarks.compactMap { data in
            return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
        }
    }

    static func saveActiveURL(_ url: URL?) {
        let bookmark = try? url?.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: activeURLKey)
    }

    static func loadActiveURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: activeURLKey) else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
}

// MARK: - Wallpaper Player (multi-screen)

class WallpaperPlayer {
    static let shared = WallpaperPlayer()

    private var wallpaperWindows: [NSWindow] = []
    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var playerLayers: [AVPlayerLayer] = []
    private var currentURL: URL?
    private var rateObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var keepAliveTimer: Timer?

    var soundEnabled: Bool = true {
        didSet {
            player?.isMuted = !soundEnabled
            UserDefaults.standard.set(soundEnabled, forKey: "settings.sound")
        }
    }

    var playbackRate: Float = 1.0 {
        didSet {
            player?.rate = playbackRate
            UserDefaults.standard.set(playbackRate, forKey: "settings.speed")
        }
    }

    var nowPlayingURL: URL? { currentURL }

    func loadSettings() {
        let d = UserDefaults.standard
        if d.object(forKey: "settings.sound") != nil {
            soundEnabled = d.bool(forKey: "settings.sound")
        }

        if d.object(forKey: "settings.speed") != nil {
            playbackRate = d.float(forKey: "settings.speed")
        }
    }

    func play(url: URL, force: Bool = false) {
        // If same URL and not forced – just ensure it's playing (don't stop)
        if !force && currentURL == url {
            if let p = player, p.timeControlStatus != .playing {
                p.play()
                p.rate = playbackRate
            }
            return
        }
        stop()
        currentURL = url
        GalleryStore.saveActiveURL(url)

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        queuePlayer.isMuted = !soundEnabled
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        player = queuePlayer
        
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        // Create a wallpaper window for every connected screen
        for screen in NSScreen.screens {
            let win = makeWallpaperWindow(for: screen)
            let layer = AVPlayerLayer(player: queuePlayer)
            layer.frame = win.contentView!.bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer.videoGravity = .resizeAspectFill
            win.contentView!.layer!.addSublayer(layer)
            win.orderFront(nil)
            wallpaperWindows.append(win)
            playerLayers.append(layer)
        }

        // Keep custom playback speed when looper loops to next item replica
        rateObserver = queuePlayer.observe(\.rate, options: [.new]) { [weak self] p, change in
            guard let self = self else { return }
            let newRate = change.newValue ?? p.rate
            // Only correct non-zero rates that don't match desired speed
            if newRate != 0 && newRate != self.playbackRate {
                p.rate = self.playbackRate
            }
        }

        // Observe timeControlStatus to auto-recover from unexpected pauses
        statusObserver = queuePlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            guard let self = self else { return }
            if p.timeControlStatus == .paused, self.currentURL != nil {
                // Small delay to avoid fighting with intentional stops
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self, weak p] in
                    guard let self = self, let p = p, self.currentURL != nil else { return }
                    if p.timeControlStatus == .paused {
                        p.play()
                        p.rate = self.playbackRate
                    }
                }
            }
        }

        // Periodic keep-alive: nudge player if unexpectedly stopped
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, let p = self.player, self.currentURL != nil else { return }
            if p.timeControlStatus == .paused {
                p.play()
                p.rate = self.playbackRate
            }
        }
        // Allow timer to fire even when runloop is in event-tracking mode
        if let timer = keepAliveTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        // Listen for screen changes
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        queuePlayer.play()
        queuePlayer.rate = playbackRate
        
        DispatchQueue.main.async {
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.updateTrayIcon()
            }
        }
    }

    func stop() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        rateObserver = nil
        statusObserver = nil
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
        player?.pause()
        playerLooper = nil
        player = nil
        playerLayers.forEach { $0.removeFromSuperlayer() }
        playerLayers.removeAll()
        wallpaperWindows.forEach { $0.orderOut(nil) }
        wallpaperWindows.removeAll()
        currentURL = nil
        GalleryStore.saveActiveURL(nil)
        
        DispatchQueue.main.async {
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.updateTrayIcon()
            }
        }
    }

    /// Nudge the player to resume if it paused unexpectedly (e.g., after window focus change).
    func ensurePlaying() {
        guard let p = player, currentURL != nil, p.timeControlStatus == .paused else { return }
        p.play()
        p.rate = playbackRate
    }

    @objc private func screensChanged() {
        guard let url = currentURL else { return }
        play(url: url, force: true)   // re-setup windows for new screen configuration
    }

    private func makeWallpaperWindow(for screen: NSScreen) -> NSWindow {
        let win = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        win.isOpaque = true
        win.backgroundColor = .black
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        win.contentView?.wantsLayer = true
        win.contentView?.layer?.backgroundColor = NSColor.black.cgColor
        return win
    }
}

// MARK: - Tray Icon

func createTrayIcon(isPlaying: Bool) -> NSImage {
    let symbolName = isPlaying ? "pause.fill" : "play.fill"
    if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) { return img }
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { _ in
        if isPlaying {
            let path1 = NSRect(x: 5, y: 4, width: 3, height: 10)
            let path2 = NSRect(x: 10, y: 4, width: 3, height: 10)
            NSColor.black.setFill()
            NSBezierPath(rect: path1).fill()
            NSBezierPath(rect: path2).fill()
        } else {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 6, y: 4))
            path.line(to: NSPoint(x: 14, y: 9))
            path.line(to: NSPoint(x: 6, y: 14))
            path.close()
            NSColor.black.setFill(); path.fill()
        }
        return true
    }
    image.isTemplate = true
    return image
}

// MARK: - Quit Button

class RedQuitButton: NSButton {
    private var trackingArea: NSTrackingArea?
    override init(frame f: NSRect) { super.init(frame: f); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }
    private func setup() {
        isBordered = false; wantsLayer = true; layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 0.9).cgColor
        let p = NSMutableParagraphStyle(); p.alignment = .center
        attributedTitle = NSAttributedString(string: "Quit Application", attributes: [
            .foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .paragraphStyle: p])
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(t); trackingArea = t
    }
    override func mouseEntered(with e: NSEvent) { super.mouseEntered(with: e); NSCursor.pointingHand.set()
        layer?.backgroundColor = NSColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1).cgColor }
    override func mouseExited(with e: NSEvent) { super.mouseExited(with: e); NSCursor.arrow.set()
        layer?.backgroundColor = NSColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 0.9).cgColor }
}

// Custom Toggle Switch removed; using standard NSSwitch

// MARK: - Custom Tab Bar (two pill buttons, not segment)

class TabBar: NSView {
    var selectedIndex: Int = 0 { didSet { updateSelection(animated: true) } }
    var changed: ((Int) -> Void)?
    private let bg = NSView()
    private let pill = NSView()
    private let btn1 = NSButton()
    private let btn2 = NSButton()

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        bg.wantsLayer = true; bg.layer?.cornerRadius = 14
        bg.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        bg.frame = bounds; addSubview(bg)

        pill.wantsLayer = true; pill.layer?.cornerRadius = 11
        pill.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.10).cgColor
        addSubview(pill)

        for (i, (btn, title)) in [(btn1, "Settings"), (btn2, "Gallery")].enumerated() {
            btn.isBordered = false; btn.wantsLayer = true
            btn.title = title; btn.tag = i
            btn.target = self; btn.action = #selector(btnTapped(_:))
            addSubview(btn)
        }
        updateSelection(animated: false)
    }

    override func layout() {
        super.layout()
        bg.frame = bounds
        let w = bounds.width / 2
        btn1.frame = NSRect(x: 0, y: 0, width: w, height: bounds.height)
        btn2.frame = NSRect(x: w, y: 0, width: w, height: bounds.height)
        updateSelection(animated: false)
    }

    @objc private func btnTapped(_ sender: NSButton) {
        if sender.tag != selectedIndex { selectedIndex = sender.tag; changed?(selectedIndex) }
    }

    private func updateSelection(animated: Bool) {
        let w = bounds.width / 2
        let pillFrame = NSRect(x: CGFloat(selectedIndex) * w + 3, y: 3, width: w - 6, height: bounds.height - 6)
        let p = NSMutableParagraphStyle(); p.alignment = .center
        let active: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .paragraphStyle: p]
        let inactive: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.tertiaryLabelColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .medium), .paragraphStyle: p]
        btn1.attributedTitle = NSAttributedString(string: "Settings", attributes: selectedIndex == 0 ? active : inactive)
        btn2.attributedTitle = NSAttributedString(string: "Gallery", attributes: selectedIndex == 1 ? active : inactive)
        if animated {
            NSAnimationContext.runAnimationGroup {
                $0.duration = 0.2; $0.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                pill.animator().frame = pillFrame
            }
        } else { pill.frame = pillFrame }
    }
}

// MARK: - Settings View

class SettingsView: NSView {
    private var soundToggle: NSSwitch?
    private var speedSlider: NSSlider?
    private var speedLabel: NSTextField?

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    func syncToPlayer() {
        soundToggle?.state = WallpaperPlayer.shared.soundEnabled ? .on : .off
        speedSlider?.doubleValue = Double(WallpaperPlayer.shared.playbackRate)
        speedLabel?.stringValue = String(format: "%.2f×", WallpaperPlayer.shared.playbackRate)
    }

    private func row(y: CGFloat, h: CGFloat, title: String, titleY: CGFloat? = nil) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: y, width: bounds.width, height: h))
        v.wantsLayer = true; v.layer?.cornerRadius = 12
        v.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
        let lbl = NSTextField(labelWithString: title)
        lbl.font = NSFont.systemFont(ofSize: 12, weight: .medium); lbl.textColor = .labelColor
        let finalY = titleY ?? (h - 16) / 2
        lbl.frame = NSRect(x: 14, y: finalY, width: 140, height: 16)
        v.addSubview(lbl)
        return v
    }

    private func setup() {
        let W = bounds.width
        let wp = WallpaperPlayer.shared
        var y = bounds.height

        // Sound
        y -= 60
        let soundRow = row(y: y, h: 44, title: "Sound")
        let sndT = NSSwitch(frame: NSRect(x: W - 54, y: 11, width: 40, height: 22))
        sndT.state = wp.soundEnabled ? .on : .off
        sndT.target = self
        sndT.action = #selector(soundToggled(_:))
        soundRow.addSubview(sndT)
        addSubview(soundRow)
        soundToggle = sndT

        // Speed
        y -= 80
        let speedRow = row(y: y, h: 64, title: "Playback Speed", titleY: 38)
        let lbl = NSTextField(labelWithString: String(format: "%.2f×", wp.playbackRate))
        lbl.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        lbl.textColor = .secondaryLabelColor; lbl.alignment = .right
        lbl.frame = NSRect(x: W - 58, y: 38, width: 44, height: 16)
        speedRow.addSubview(lbl)
        speedLabel = lbl

        let slider = NSSlider(frame: NSRect(x: 14, y: 10, width: W - 28, height: 20))
        slider.minValue = 0.25; slider.maxValue = 3.0
        slider.doubleValue = Double(wp.playbackRate)
        slider.isContinuous = true
        slider.target = self; slider.action = #selector(speedChanged(_:))
        speedRow.addSubview(slider)
        addSubview(speedRow)
        speedSlider = slider
    }

    @objc private func soundToggled(_ s: NSSwitch) {
        WallpaperPlayer.shared.soundEnabled = (s.state == .on)
    }

    @objc private func speedChanged(_ s: NSSlider) {
        WallpaperPlayer.shared.playbackRate = Float(s.doubleValue)
        speedLabel?.stringValue = String(format: "%.2f×", s.doubleValue)
    }
}

// MARK: - Card Icon Button (square)

class CardIconButton: NSButton {
    private var trackingArea: NSTrackingArea?
    init(frame: NSRect, sym: String, color: NSColor = .white) {
        super.init(frame: frame); isBordered = false; wantsLayer = true
        layer?.cornerRadius = 5
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        if let img = NSImage(systemSymbolName: sym, accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
            image = img.withSymbolConfiguration(cfg); image?.isTemplate = true; contentTintColor = color
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(t); trackingArea = t
    }
    override func mouseEntered(with e: NSEvent) { super.mouseEntered(with: e)
        NSCursor.pointingHand.set(); layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor }
    override func mouseExited(with e: NSEvent) { super.mouseExited(with: e)
        NSCursor.arrow.set(); layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor }
}

// MARK: - Gallery Card

class GalleryCardView: NSView {
    private var tracking: NSTrackingArea?
    let item: GalleryView.GalleryItem
    var onDelete: (() -> Void)?
    var onShowInFinder: (() -> Void)?
    var onTap: (() -> Void)?
    private let deleteBtn: CardIconButton
    private let finderBtn: CardIconButton
    private let playingOverlay = NSView()
    private let playingImageView = NSImageView()
    private(set) var isPlaying = false
    private var isHovered = false

    init(frame: NSRect, item: GalleryView.GalleryItem) {
        self.item = item
        let w = frame.width, h = frame.height
        deleteBtn = CardIconButton(frame: NSRect(x: w - 24, y: h - 24, width: 20, height: 20), sym: "xmark", color: .systemRed)
        finderBtn = CardIconButton(frame: NSRect(x: w - 48, y: h - 24, width: 20, height: 20), sym: "folder.fill")
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        wantsLayer = true; layer?.cornerRadius = 10; layer?.masksToBounds = true
        if let t = item.thumbnail, let cg = t.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            layer?.contents = cg; layer?.contentsGravity = .resizeAspectFill
        } else {
            let g = CAGradientLayer(); g.frame = bounds
            g.colors = item.colors.map { $0.cgColor }
            g.startPoint = CGPoint(x: 0, y: 0); g.endPoint = CGPoint(x: 1, y: 1)
            layer?.addSublayer(g)
        }
        // Title bar
        let tb = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: 28))
        tb.wantsLayer = true; tb.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        let lbl = NSTextField(labelWithString: item.title)
        lbl.font = NSFont.systemFont(ofSize: 9, weight: .semibold); lbl.textColor = .white
        lbl.alignment = .center; lbl.lineBreakMode = .byTruncatingMiddle
        lbl.frame = NSRect(x: 4, y: 5, width: bounds.width - 8, height: 16)
        tb.addSubview(lbl); addSubview(tb)

        // Now-playing badge
        let bw: CGFloat = 36
        playingOverlay.frame = NSRect(x: CGFloat(Int((bounds.width - bw) / 2)), y: CGFloat(Int((bounds.height - bw) / 2)), width: bw, height: bw)
        playingOverlay.wantsLayer = true; playingOverlay.layer?.cornerRadius = bw / 2
        playingOverlay.layer?.masksToBounds = true
        playingOverlay.alphaValue = 0

        let ve = NSVisualEffectView(frame: playingOverlay.bounds)
        ve.material = .hudWindow
        ve.blendingMode = .withinWindow
        ve.state = .active
        ve.wantsLayer = true
        ve.layer?.cornerRadius = bw / 2
        ve.layer?.borderWidth = 1.0
        ve.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        playingOverlay.addSubview(ve)

        playingImageView.frame = NSRect(x: 10, y: 9, width: 18, height: 18)
        let cfg = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        playingImageView.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
        playingImageView.image?.isTemplate = true
        playingImageView.contentTintColor = .white
        ve.addSubview(playingImageView)
        
        addSubview(playingOverlay)

        // Hover buttons
        [deleteBtn, finderBtn].forEach { $0.alphaValue = 0 }
        deleteBtn.target = self; deleteBtn.action = #selector(delTapped)
        finderBtn.target = self; finderBtn.action = #selector(finderTapped)
        addSubview(deleteBtn)
        if item.videoURL != nil { addSubview(finderBtn) }
    }

    func setPlaying(_ on: Bool) {
        isPlaying = on
        updateOverlayState()
    }

    private func updateOverlayState() {
        let showOverlay = isPlaying || isHovered
        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        let cfg = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        playingImageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
        playingImageView.image?.isTemplate = true
        playingImageView.contentTintColor = .white
        
        let xOffset: CGFloat = (symbolName == "play.fill") ? 10 : 9
        playingImageView.frame = NSRect(x: xOffset, y: 9, width: 18, height: 18)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            playingOverlay.animator().alphaValue = showOverlay ? 1.0 : 0.0
        }
    }

    @objc private func delTapped() { onDelete?() }
    @objc private func finderTapped() { onShowInFinder?() }

    override func mouseDown(with e: NSEvent) { onTap?() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(t); tracking = t
    }
    override func mouseEntered(with e: NSEvent) {
        super.mouseEntered(with: e)
        isHovered = true
        updateOverlayState()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15
            deleteBtn.animator().alphaValue = 1; finderBtn.animator().alphaValue = 1 }
    }
    override func mouseExited(with e: NSEvent) {
        super.mouseExited(with: e)
        isHovered = false
        updateOverlayState()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15
            deleteBtn.animator().alphaValue = 0; finderBtn.animator().alphaValue = 0 }
    }
}

// MARK: - Gallery View

class GalleryView: NSView {
    struct GalleryItem {
        let title: String
        let colors: [NSColor]
        let videoURL: URL?
        let thumbnail: NSImage?
    }

    private let scrollView = NSScrollView()
    private let docView = NSView()
    private let addBtn = MinimalAddButton()
    private(set) var items: [GalleryItem] = []
    private var cards: [GalleryCardView] = []

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        addBtn.frame = NSRect(x: (bounds.width - 110) / 2, y: 8, width: 110, height: 26)
        addBtn.target = self; addBtn.action = #selector(addTapped)
        addSubview(addBtn)

        scrollView.frame = NSRect(x: 0, y: 42, width: bounds.width, height: bounds.height - 42)
        scrollView.hasVerticalScroller = true; scrollView.drawsBackground = false
        scrollView.documentView = docView; addSubview(scrollView)
    }

    func loadSavedItems() {
        let urls = GalleryStore.loadItems()
        for url in urls {
            // Using bookmarks so we bypass fileExists(atPath:) issues where paths get sandbox-blocked
            let thumb = makeThumbnail(url: url)
            let colors = randomColors()
            items.append(GalleryItem(title: url.lastPathComponent, colors: colors, videoURL: url, thumbnail: thumb))
        }
        layout()
        refreshPlayingState()
    }

    func addItem(url: URL) {
        let thumb = makeThumbnail(url: url)
        items.append(GalleryItem(title: url.lastPathComponent, colors: randomColors(), videoURL: url, thumbnail: thumb))
        GalleryStore.saveItems(items)
        layout()
        refreshPlayingState()
    }

    private func randomColors() -> [NSColor] {
        (0..<2).map { _ in NSColor(red: CGFloat.random(in: 0.2...0.8), green: CGFloat.random(in: 0.2...0.8), blue: CGFloat.random(in: 0.2...0.8), alpha: 1) }
    }

    private func makeThumbnail(url: URL) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        for t in [1.0, 0.0] {
            if let cg = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) {
                return NSImage(cgImage: cg, size: .zero)
            }
        }
        return nil
    }

    @objc private func addTapped() {
        let panel = NSOpenPanel()
        panel.title = "Select Video"; panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false; panel.canChooseFiles = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        addItem(url: url)
    }

    func refreshPlayingState() {
        let nowURL = WallpaperPlayer.shared.nowPlayingURL
        cards.forEach { $0.setPlaying($0.item.videoURL == nowURL && nowURL != nil) }
    }

    override func layout() {
        super.layout()
        docView.subviews.forEach { $0.removeFromSuperview() }
        cards.removeAll()
        let aw = scrollView.contentSize.width
        let cw: CGFloat = 116, ch: CGFloat = 95, gap: CGFloat = 10, cols = 2
        let rows = max(1, Int(ceil(Double(items.count) / Double(cols))))
        let contentH = max(scrollView.contentSize.height, CGFloat(rows) * (ch + gap) + gap)
        docView.frame = NSRect(x: 0, y: 0, width: aw, height: contentH)

        for (i, item) in items.enumerated() {
            let col = i % cols, row = i / cols
            let lx = (aw - (CGFloat(cols) * cw + CGFloat(cols - 1) * gap)) / 2
            let x = lx + CGFloat(col) * (cw + gap)
            let y = contentH - ch - gap - CGFloat(row) * (ch + gap)
            let card = GalleryCardView(frame: NSRect(x: x, y: y, width: cw, height: ch), item: item)
            let idx = i
            card.onTap = { [weak self] in
                guard let self = self else { return }
                if let url = self.items[idx].videoURL {
                    WallpaperPlayer.shared.play(url: url)
                }
                self.refreshPlayingState()
            }
            card.onDelete = { [weak self] in
                guard let self = self else { return }
                if let url = self.items[idx].videoURL, WallpaperPlayer.shared.nowPlayingURL == url {
                    WallpaperPlayer.shared.stop()
                }
                self.items.remove(at: idx)
                GalleryStore.saveItems(self.items)
                self.layout()
            }
            card.onShowInFinder = {
                if let url = item.videoURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            docView.addSubview(card); cards.append(card)
        }
        refreshPlayingState()
    }
}

// MARK: - Minimal Add Button

class MinimalAddButton: NSButton {
    private var tracking: NSTrackingArea?
    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }
    private func setup() {
        isBordered = false; wantsLayer = true
        layer?.cornerRadius = 8; layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        layer?.backgroundColor = NSColor.clear.cgColor
        let p = NSMutableParagraphStyle(); p.alignment = .center
        attributedTitle = NSAttributedString(string: "+ Add Video", attributes: [
            .foregroundColor: NSColor.white.withAlphaComponent(0.75),
            .font: NSFont.systemFont(ofSize: 11, weight: .medium), .paragraphStyle: p])
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(t); tracking = t
    }
    override func mouseEntered(with e: NSEvent) { super.mouseEntered(with: e)
        NSCursor.pointingHand.set()
        layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        let p = NSMutableParagraphStyle(); p.alignment = .center
        attributedTitle = NSAttributedString(string: "+ Add Video", attributes: [
            .foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 11, weight: .semibold), .paragraphStyle: p])
    }
    override func mouseExited(with e: NSEvent) { super.mouseExited(with: e)
        NSCursor.arrow.set()
        layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        layer?.backgroundColor = NSColor.clear.cgColor
        let p = NSMutableParagraphStyle(); p.alignment = .center
        attributedTitle = NSAttributedString(string: "+ Add Video", attributes: [
            .foregroundColor: NSColor.white.withAlphaComponent(0.75),
            .font: NSFont.systemFont(ofSize: 11, weight: .medium), .paragraphStyle: p])
    }
}

// MARK: - Main Window

class MainWindow: NSPanel, NSWindowDelegate {
    var lastResignTime: TimeInterval = 0
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        isReleasedWhenClosed = false; delegate = self
        isMovableByWindowBackground = false; backgroundColor = .clear; hasShadow = true
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    func windowDidResignKey(_ notification: Notification) {
        lastResignTime = ProcessInfo.processInfo.systemUptime; orderOut(nil)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var window: MainWindow?
    var settingsView: SettingsView?
    var galleryView: GalleryView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set Dock Icon dynamically
        if let iconURL = Bundle.main.url(forResource: "app_icon", withExtension: "webp"),
           let image = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = image.croppedToSquare() ?? image
        }

        WallpaperPlayer.shared.loadSettings()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem?.button {
            btn.image = createTrayIcon(isPlaying: false)
            btn.action = #selector(trayClicked(_:)); btn.target = self
        }
        setupWindow()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.galleryView?.loadSavedItems()
            // Auto-restore last wallpaper
            if let url = GalleryStore.loadActiveURL() {
                WallpaperPlayer.shared.play(url: url)
                self.galleryView?.refreshPlayingState()
            }
            self.showNearTray()
        }
    }

    func setupWindow() {
        let W: CGFloat = 300, H: CGFloat = 400
        let panel = MainWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H))

        let fx = NSVisualEffectView(frame: panel.contentView!.bounds)
        fx.autoresizingMask = [.width, .height]; fx.state = .active
        fx.material = .hudWindow; fx.blendingMode = .behindWindow
        fx.wantsLayer = true; fx.layer?.cornerRadius = 18; fx.layer?.masksToBounds = true
        panel.contentView?.addSubview(fx)

        // Tab bar
        let tabs = TabBar(frame: NSRect(x: 20, y: H - 62, width: W - 40, height: 34))
        tabs.changed = { [weak self] i in self?.switchTab(i) }
        fx.addSubview(tabs)

        // Divider
        let div = NSView(frame: NSRect(x: 20, y: H - 68, width: W - 40, height: 1))
        div.wantsLayer = true; div.layer?.backgroundColor = NSColor.separatorColor.cgColor
        fx.addSubview(div)

        // Content
        let container = NSView(frame: NSRect(x: 20, y: 72, width: W - 40, height: H - 68 - 72 - 4))
        fx.addSubview(container)

        let settings = SettingsView(frame: container.bounds)
        let gallery = GalleryView(frame: container.bounds)
        gallery.isHidden = true
        container.addSubview(settings); container.addSubview(gallery)
        settingsView = settings; galleryView = gallery

        // Quit button
        let quit = RedQuitButton(frame: NSRect(x: 20, y: 20, width: W - 40, height: 40))
        quit.target = self; quit.action = #selector(quitClicked(_:))
        fx.addSubview(quit)

        self.window = panel
    }

    func switchTab(_ i: Int) {
        settingsView?.isHidden = i != 0
        galleryView?.isHidden = i != 1
        if i == 0 { settingsView?.syncToPlayer() }
    }

    @objc func trayClicked(_ sender: AnyObject?) { toggleWindow() }
    @objc func quitClicked(_ sender: AnyObject?) { NSApp.terminate(nil) }

    func updateTrayIcon() {
        if let btn = statusItem?.button {
            btn.image = createTrayIcon(isPlaying: WallpaperPlayer.shared.nowPlayingURL != nil)
        }
    }

    func toggleWindow() {
        guard let w = window else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - w.lastResignTime < 0.25 { return }
        if w.isVisible {
            w.orderOut(nil)
        } else {
            // Ensure playback is running before showing UI (window focus can sometimes cause a brief stall)
            WallpaperPlayer.shared.ensurePlaying()
            showNearTray()
        }
    }

    func showNearTray() {
        guard let w = window else { return }
        if let btn = statusItem?.button, let wf = btn.window?.frame {
            let sf = NSScreen.main?.visibleFrame ?? .zero
            if wf.origin.y < sf.maxY - 120 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.showNearTray() }
                return
            }
            var x = wf.origin.x + wf.width / 2 - w.frame.width / 2
            var y = wf.origin.y - w.frame.height - 5
            x = max(sf.minX + 10, min(x, sf.maxX - w.frame.width - 10))
            y = max(sf.minY + 10, y)
            w.setFrameOrigin(NSPoint(x: x, y: y))
        } else { w.center() }
        w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let w = window else { return true }
        if w.isVisible { w.orderOut(nil) } else { showNearTray() }
        return true
    }
}

// MARK: - Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
