import AppKit
import Combine
import QuartzCore
import SwiftUI
import FileMintCore

@MainActor
private final class DrawerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    var requestClose: (() -> Void)?
    weak var drawer: FileDrawerModel?
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isKeyWindow, let drawer, drawer.presented, let binding = FileDrawerCommand.binding(for: event) else {
            return super.performKeyEquivalent(with: event)
        }
        let command = binding.command
        if attachedSheet != nil || NSApp.modalWindow != nil || drawer.interacting || drawer.writing ||
            drawer.dragging || drawer.pathMenu != nil || drawer.draftWindow?.isVisible == true ||
            (firstResponder as? NSTextView)?.hasMarkedText() == true {
            // A withheld drawer command must not fall through to FileMint's File menu.
            switch command {
            case .newFile, .newFolder, .close, .pin, .togglePlaces, .goToPlaceMenu, .actions, .place: return true
            default: return super.performKeyEquivalent(with: event)
            }
        }
        if let palette = drawer.actionPalette {
            if let action = binding.paletteAction {
                drawer.performPaletteAction(action, session: palette.id)
                return true
            }
            switch command {
            case .actions, .close: drawer.closeActionPalette(); return true
            case .newFile, .newFolder, .togglePlaces, .goToPlaceMenu, .pin, .place: return true
            default: return super.performKeyEquivalent(with: event)
            }
        }
        if command.runWindowCommand(in: drawer) { return true }
        return super.performKeyEquivalent(with: event)
    }
    override func performClose(_ sender: Any?) { requestClose?() }
}

@MainActor
final class FileDrawerController: NSObject, NSWindowDelegate {
    static let shared = FileDrawerController(settings: .shared, favorites: .shared)

    /// AppKit can deliver a menu equivalent before the key panel's responder chain.
    static func handleFavoriteMenuKey(_ event: NSEvent?) -> Bool {
        guard let event, event.type == .keyDown, FileDrawerCommand.match(event) == .actions,
              let panel = NSApp.keyWindow as? DrawerPanel else { return false }
        return panel.performKeyEquivalent(with: event)
    }
    let model: FileDrawerModel
    private let settings: PreferencesModel
    private let reduceMotion: @MainActor () -> Bool
    private(set) var panel: NSPanel?
    private var preferenceObserver: AnyCancellable?
    private var previousApp: pid_t?
    private var background: DrawerBackground?
    private var grip: DrawerGrip?
    private var edgeConstraint: NSLayoutConstraint?
    private var display: NSScreen?
    private var requestedFrame: CGRect?
    private var closing = false
    private static let transitionKey = "drawerVisibility"
    private var transitionID = UUID()
    private var layerAnimation: FileDrawerPreferences.Animation = .slide
    private var genieTransition: FileDrawerGenieTransition?
    private var draggingWidth = false
    private var trackingMenus: Set<ObjectIdentifier> = []

    init(settings: PreferencesModel, favorites: FavoriteLocationsModel,
         placeHome: URL = DefaultFolders.resolvedUserHomeDirectory(fileManager: .default),
         lastLocationKey: String = "fileDrawer.lastLocation",
         reduceMotion: @escaping @MainActor () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
        self.settings = settings
        self.reduceMotion = reduceMotion
        self.model = FileDrawerModel(settings: settings, favorites: favorites, placeHome: placeHome, lastLocationKey: lastLocationKey)
        super.init()
        preferenceObserver = settings.$committedPreferences.map(\.fileDrawer).removeDuplicates().sink { [weak self] _ in
            // @Published delivers before the containing snapshot has been assigned.
            Task { @MainActor [weak self] in guard let self else { return }; self.apply(self.settings.committedPreferences.fileDrawer) }
        }
    }

    func toggle() {
        if panel == nil || closing { show() }
        else if !hasActiveInteraction { dismiss() }
    }

    func toggleFromShortcut() {
        guard settings.committedPreferences.fileDrawer.enabled else { return }
        if let modal = NSApp.modalWindow ?? NSApp.windows.compactMap(\.attachedSheet).first {
            modal.makeKeyAndOrderFront(nil)
            return
        }
        guard !hasActiveInteraction, model.pathMenu == nil else { return }
        if let panel, panel.isKeyWindow, !closing {
            dismiss()
        } else {
            show()
        }
    }

    func show() { show(on: pointerScreen) }

    func show(on targetScreen: NSScreen?) {
        guard settings.committedPreferences.fileDrawer.enabled else { return }
        if let modal = NSApp.modalWindow ?? NSApp.windows.compactMap(\.attachedSheet).first {
            modal.makeKeyAndOrderFront(nil)
            return
        }
        if let panel {
            let reopening = closing
            closing = false
            if !hasActiveInteraction, let screen = targetScreen, display != screen {
                display = screen
                requestedFrame = nil
                layout(settings.committedPreferences.fileDrawer)
            }
            if reopening { transition(opening: true) }
            panel.makeKeyAndOrderFront(nil)
            return
        }
        guard !model.writing, let screen = targetScreen else { return }
        display = screen
        previousApp = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let p = DrawerPanel(contentRect: .init(x: 0, y: 0, width: 520, height: 650),
                            styleMask: [.borderless, .nonactivatingPanel, .closable], backing: .buffered, defer: false)
        p.identifier = .init("io.github.daigua.filemint.drawer")
        p.title = model.text("File Drawer", "文件抽屉")
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.animationBehavior = .none
        p.isReleasedWhenClosed = false
        p.isOpaque = false
        p.hasShadow = true
        p.backgroundColor = .clear
        p.collectionBehavior = [.moveToActiveSpace,.fullScreenAuxiliary]
        p.delegate = self
        p.drawer = model
        p.requestClose = { [weak self] in
            guard let self, !self.hasActiveInteraction, self.model.pathMenu == nil, self.panel?.attachedSheet == nil else { return }
            self.dismiss()
        }
        let backdrop = DrawerBackground()
        let content = NSHostingView(rootView: FileDrawerView(model: model, settings: settings).fileMintTheme())
        let handle = DrawerGrip()
        handle.setAccessibilityLabel(model.text("Resize file drawer", "调整抽屉宽度"))
        handle.resize = { [weak self] delta, finished in self?.resize(by: delta, finished: finished) }
        for view in [content as NSView, handle] {
            view.translatesAutoresizingMaskIntoConstraints = false
            backdrop.controls.addSubview(view)
        }
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: backdrop.controls.leadingAnchor, constant: 7),
            content.trailingAnchor.constraint(equalTo: backdrop.controls.trailingAnchor, constant: -7),
            content.topAnchor.constraint(equalTo: backdrop.controls.topAnchor),
            content.bottomAnchor.constraint(equalTo: backdrop.controls.bottomAnchor),
            handle.widthAnchor.constraint(equalToConstant: 8),
            handle.topAnchor.constraint(equalTo: backdrop.controls.topAnchor, constant: 16),
            handle.bottomAnchor.constraint(equalTo: backdrop.controls.bottomAnchor, constant: -16)
        ])
        // Clip the edge transition at a seam between two displays.
        let clip = NSView()
        clip.wantsLayer = true
        clip.layer?.masksToBounds = true
        backdrop.frame = clip.bounds
        backdrop.autoresizingMask = [.width, .height]
        clip.addSubview(backdrop)
        p.contentView = clip
        panel = p
        model.window = p
        background = backdrop
        grip = handle
        apply(settings.committedPreferences.fileDrawer)
        model.start()
        p.contentView?.layoutSubtreeIfNeeded()
        transition(opening: true)
        p.makeKeyAndOrderFront(nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuBegan(_:)), name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuEnded(_:)), name: NSMenu.didEndTrackingNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(activated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        workspace.addObserver(self, selector: #selector(accessibilityChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displayChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private var autoPreview: Bool?
    private func apply(_ value: FileDrawerPreferences) {
        guard let panel else { return }
        guard value.enabled else { panel.close(); return }
        if let background, let grip {
            edgeConstraint?.isActive = false
            edgeConstraint = value.side == .right ? grip.leadingAnchor.constraint(equalTo: background.controls.leadingAnchor)
                : grip.trailingAnchor.constraint(equalTo: background.controls.trailingAnchor)
            edgeConstraint?.isActive = true
            background.apply(value)
        }
        layout(value)
        if autoPreview != value.autoPreview {
            autoPreview = value.autoPreview
            model.schedulePreview()
        }
    }

    private var pointerScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
    }

    private func layout(_ options: FileDrawerPreferences) {
        guard let screen = display, let panel else { return }
        let rect = options.panelFrame(in: screen.visibleFrame)
        // AppKit rounds some frame coordinates. Compare layout requests so an
        // unrelated preference save cannot cancel a transition on a rounded frame.
        guard rect != requestedFrame else { return }
        requestedFrame = rect
        if panel.frame != rect {
            finishTransition(transitionID)
            if self.panel === panel { panel.setFrame(rect, display: true) }
        }
    }

    private func resize(by dx: CGFloat, finished: Bool) {
        guard let panel, dx != 0 || draggingWidth else { return }
        var options = settings.committedPreferences.fileDrawer
        draggingWidth = !finished
        options.fitsDisplayWidth = false
        options.width = panel.frame.width + (options.side == .left ? dx : -dx)
        layout(options)
        if finished {
            options.width = min(options.maximumWidth, max(options.minimumWidth, panel.frame.width))
            if !settings.setFileDrawer(options) { apply(settings.committedPreferences.fileDrawer) }
        }
    }

    @objc private func displayChanged() {
        let number = NSDeviceDescriptionKey("NSScreenNumber")
        let id = display?.deviceDescription[number] as? NSNumber
        display = NSScreen.screens.first { $0.deviceDescription[number] as? NSNumber == id } ?? pointerScreen
        requestedFrame = nil
        finishTransition(transitionID)
        apply(settings.committedPreferences.fileDrawer)
    }

    func windowDidChangeBackingProperties(_ notification: Notification) {
        guard genieTransition != nil, let window = notification.object as? NSWindow, window === panel,
              let previousScale = notification.userInfo?[NSWindow.oldScaleFactorUserInfoKey] as? NSNumber,
              previousScale.doubleValue != window.backingScaleFactor else { return }
        finishTransition(transitionID)
    }

    @objc private func accessibilityChanged() {
        if reduceMotion() { finishTransition(transitionID) }
        apply(settings.committedPreferences.fileDrawer)
    }
    @objc private func activated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier, app.processIdentifier != previousApp else { return }
        dismissWhenIdle()
    }
    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self, weak window = notification.object as? NSWindow] in
            guard let self, let window, self.panel === window, !window.isKeyWindow else { return }
            self.dismissWhenIdle()
        }
    }
    @objc private func menuBegan(_ note: Notification) {
        if let menu = note.object as? NSMenu { trackingMenus.insert(ObjectIdentifier(menu)) }
    }
    @objc private func menuEnded(_ note: Notification) {
        if let menu = note.object as? NSMenu { trackingMenus.remove(ObjectIdentifier(menu)) }
    }
    private var hasActiveInteraction: Bool {
        model.dragging || draggingWidth || model.interacting || model.writing ||
            model.actionPalette != nil || model.draftWindow?.isVisible == true || !trackingMenus.isEmpty
    }
    private func dismissWhenIdle() {
        guard !model.pinned, !hasActiveInteraction, model.pathMenu == nil,
              panel?.attachedSheet == nil, NSApp.modalWindow == nil else { return }
        dismiss()
    }

    private func dismiss() {
        guard panel != nil, !closing else { return }
        closing = true
        transition(opening: false)
    }

    private func transition(opening: Bool) {
        let id = UUID()
        transitionID = id
        guard !reduceMotion(), let panel, let background, let layer = background.layer else {
            finishTransition(id)
            return
        }
        let options = settings.committedPreferences.fileDrawer
        let running = layer.animation(forKey: Self.transitionKey) != nil
        if let genieTransition {
            genieTransition.play(opening: opening) { [weak self] in self?.finishTransition(id) }
            return
        }
        if !running, options.animation == .genie, let clip = panel.contentView {
            let updateBackdrop = background.genieBackdropUpdate()
            if updateBackdrop != nil || !background.showsGlass,
               let image = background.transitionImage(includeBackground: updateBackdrop == nil),
               let genie = FileDrawerGenieTransition(image: image, frame: background.frame, side: options.side,
                                                     opening: opening, framesPerSecond: display?.maximumFramesPerSecond ?? 0,
                                                     updateBackdrop: updateBackdrop) {
                genieTransition = genie
                if opening, model.busy, model.directory == nil {
                    let includeBackground = updateBackdrop == nil
                    genie.restoredOpeningImage = { [weak model, weak background] in
                        guard let model, model.directory != nil, !model.busy, !model.isSearching else { return nil }
                        return background?.transitionImage(includeBackground: includeBackground)
                    }
                }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                clip.addSubview(genie, positioned: .above, relativeTo: background)
                if updateBackdrop == nil { layer.opacity = 0 }
                else { background.controls.layer?.opacity = 0 }
                CATransaction.commit()
                genie.play(opening: opening) { [weak self] in self?.finishTransition(id) }
                return
            }
        }
        let animation = running ? layerAnimation : options.animation
        layerAnimation = animation == .scale ? .scale : .slide
        animateLayer(layer, animation: layerAnimation, side: options.side, opening: opening, id: id)
    }

    private func animateLayer(_ layer: CALayer, animation: FileDrawerPreferences.Animation, side: FileDrawerPreferences.Side,
                              opening: Bool, id: UUID) {
        let current = layer.animation(forKey: Self.transitionKey) == nil ? nil : layer.presentation()
        let targetOpacity: Float = opening ? 1 : 0
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = current?.opacity ?? (opening ? 0 : 1)
        fade.toValue = targetOpacity
        let hiddenTransform: CATransform3D
        let motion: CABasicAnimation
        let group = CAAnimationGroup()
        if animation == .scale {
            let scale: CGFloat = 0.7
            let edge: CGFloat = side == .right ? 1 : 0
            let x = (edge - layer.anchorPoint.x) * layer.bounds.width * (1 - scale)
            let y = (0.5 - layer.anchorPoint.y) * layer.bounds.height * (1 - scale)
            hiddenTransform = CATransform3DMakeAffineTransform(.init(a: scale, b: 0, c: 0, d: scale, tx: x, ty: y))
            motion = CABasicAnimation(keyPath: "transform")
            motion.fromValue = NSValue(caTransform3D: current?.transform ?? (opening ? hiddenTransform : CATransform3DIdentity))
            motion.toValue = NSValue(caTransform3D: opening ? CATransform3DIdentity : hiddenTransform)
            group.duration = opening ? 0.22 : 0.18
        } else {
            let edge: CGFloat = side == .right ? 8 : -8
            hiddenTransform = CATransform3DMakeTranslation(edge, 0, 0)
            motion = CABasicAnimation(keyPath: "transform.translation.x")
            motion.fromValue = current?.transform.m41 ?? (opening ? edge : 0)
            motion.toValue = opening ? 0 : edge
            group.duration = opening ? 0.16 : 0.12
        }
        fade.duration = group.duration
        motion.duration = group.duration
        group.animations = [fade, motion]
        group.timingFunction = CAMediaTimingFunction(name: opening ? .easeOut : .easeIn)
        if let fps = display?.maximumFramesPerSecond, fps > 0 {
            let maximum = Float(fps)
            group.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, maximum), maximum: maximum, preferred: maximum)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = opening ? CATransform3DIdentity : hiddenTransform
        layer.opacity = targetOpacity
        CATransaction.setCompletionBlock { [weak self] in
            Task { @MainActor in self?.finishTransition(id) }
        }
        layer.add(group, forKey: Self.transitionKey)
        CATransaction.commit()
    }

    private func finishTransition(_ id: UUID) {
        guard transitionID == id else { return }
        if closing { panel?.close() }
        else { resetTransition(revealDrawer: true) }
    }

    private func resetTransition(revealDrawer: Bool) {
        transitionID = UUID()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let layer = background?.layer {
            layer.removeAnimation(forKey: Self.transitionKey)
            layer.transform = CATransform3DIdentity
            layer.opacity = revealDrawer ? 1 : 0
        }
        background?.clearGenieBackdrop()
        genieTransition?.discard()
        genieTransition = nil
        CATransaction.commit()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSPanel, closing === panel else { return }
        // Take the window offscreen before removing its last composited frame.
        closing.orderOut(nil)
        trackingMenus.removeAll()
        self.closing = false
        resetTransition(revealDrawer: false)
        model.end()
        if let sheet = closing.attachedSheet { closing.endSheet(sheet, returnCode: .cancel) }
        model.interacting = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        model.window = nil
        panel = nil
        grip = nil
        background = nil
        edgeConstraint = nil
        display = nil
        requestedFrame = nil
        autoPreview = nil
        draggingWidth = false
    }
}

private final class DrawerBackground: NSView {
    let controls = NSView()
    private let material = NSView()
    private let effect = NSVisualEffectView()
    private let solid = NSBox()
    private let genieMask = CAShapeLayer()

    var showsGlass: Bool { !effect.isHidden }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        effect.blendingMode = .behindWindow
        effect.material = .popover
        effect.state = .followsWindowActiveState
        solid.boxType = .custom
        solid.borderWidth = 0
        solid.titlePosition = .noTitle
        solid.fillColor = .windowBackgroundColor
        material.wantsLayer = true
        controls.wantsLayer = true
        for view in [material, controls] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
        for view in [effect as NSView, solid] {
            view.frame = material.bounds
            view.autoresizingMask = [.width, .height]
            material.addSubview(view)
        }
    }
    required init?(coder: NSCoder) { nil }

    func transitionImage(includeBackground: Bool) -> CGImage? {
        controls.layoutSubtreeIfNeeded()
        guard !controls.bounds.isEmpty, let bitmap = controls.bitmapImageRepForCachingDisplay(in: controls.bounds) else { return nil }
        // A restored listing can arrive after the live controls have been hidden behind the mesh.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let previousOpacity = controls.layer?.opacity ?? 1
        controls.layer?.opacity = 1
        controls.cacheDisplay(in: controls.bounds, to: bitmap)
        controls.layer?.opacity = previousOpacity
        CATransaction.commit()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else { return nil }
        let pixels = CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        let radius = layer?.cornerRadius ?? 0
        let outline = CGPath(roundedRect: pixels, cornerWidth: radius * pixels.width / bounds.width,
                             cornerHeight: radius * pixels.height / bounds.height, transform: nil)
        if includeBackground {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                context.setFillColor(solid.fillColor.withAlphaComponent(1).cgColor)
                context.setBlendMode(.destinationOver)
                context.addPath(outline)
                context.fillPath()
            }
        }
        context.setBlendMode(.clear)
        context.addRect(pixels)
        context.addPath(outline)
        context.fillPath(using: .evenOdd)
        return context.makeImage()
    }

    func genieBackdropUpdate() -> FileDrawerGenieTransition.BackdropUpdate? {
        guard showsGlass, !material.bounds.isEmpty, let layer = material.layer else { return nil }
        let size = material.bounds.size
        // Clip the live glass and its tint together at the backing scale.
        genieMask.frame = material.bounds
        genieMask.contentsScale = window?.backingScaleFactor ?? 1
        let edgeCount = FileDrawerGenieGeometry.columns + 1
        return { [weak self] vertices, opacity in
            guard let self else { return }
            let outline = Array(vertices.prefix(edgeCount)) + vertices.suffix(edgeCount).reversed()
            let path = CGMutablePath()
            path.addLines(between: outline.map { CGPoint(x: CGFloat($0.x) * size.width, y: CGFloat($0.y) * size.height) })
            path.closeSubpath()
            genieMask.path = path
            genieMask.opacity = Float(opacity)
            if layer.mask == nil { layer.mask = genieMask }
        }
    }

    func clearGenieBackdrop() {
        controls.layer?.opacity = 1
        material.layer?.mask = nil
        genieMask.path = nil
    }

    func apply(_ options: FileDrawerPreferences) {
        let glass = options.glass && !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        effect.isHidden = !glass
        // At the default, use AppKit's material unchanged. Mix toward the
        // system window color below it or lighten just the backdrop above it.
        let standard = FileDrawerPreferences().transparency
        solid.alphaValue = glass ? max(0, 1 - options.transparency / standard) : 1
        effect.alphaValue = 1 - max(0, options.transparency - standard) / (1 - standard) * 0.4
    }
}

private final class DrawerGrip: NSView {
    var resize: ((CGFloat, Bool) -> Void)?
    private var x: CGFloat?
    override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeLeftRight) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setFill()
        NSBezierPath(roundedRect: .init(x: bounds.midX - 1.5, y: bounds.midY - 16, width: 3, height: 32),
                     xRadius: 1.5, yRadius: 1.5).fill()
    }
    override func mouseDown(with event: NSEvent) { x = NSEvent.mouseLocation.x }
    override func mouseDragged(with event: NSEvent) {
        guard let x else { return }
        let next = NSEvent.mouseLocation.x
        resize?(next - x, false)
        self.x = next
    }
    override func mouseUp(with event: NSEvent) {
        guard x != nil else { return }
        x = nil
        resize?(0, true)
    }
}
