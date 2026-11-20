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
    private(set) var panel: NSPanel?
    private var preferenceObserver: AnyCancellable?
    private var previousApp: pid_t?
    private var background: DrawerBackground?
    private var grip: DrawerGrip?
    private var edgeConstraint: NSLayoutConstraint?
    private var display: NSScreen?
    private var closing = false
    private static let transitionKey = "drawerVisibility"
    private var transitionID = UUID()
    private var draggingWidth = false
    private var trackingMenus: Set<ObjectIdentifier> = []

    init(settings: PreferencesModel, favorites: FavoriteLocationsModel,
         placeHome: URL = DefaultFolders.resolvedUserHomeDirectory(fileManager: .default),
         lastLocationKey: String = "fileDrawer.lastLocation") {
        self.settings = settings
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

    func show() {
        guard settings.committedPreferences.fileDrawer.enabled else { return }
        if let modal = NSApp.modalWindow ?? NSApp.windows.compactMap(\.attachedSheet).first {
            modal.makeKeyAndOrderFront(nil)
            return
        }
        if let panel {
            if !hasActiveInteraction, let screen = pointerScreen, display != screen {
                display = screen
                layout(settings.committedPreferences.fileDrawer)
            }
            if closing {
                closing = false
                transition(opening: true)
            }
            panel.makeKeyAndOrderFront(nil)
            return
        }
        guard !model.writing, let screen = pointerScreen else { return }
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
        let content = NSHostingView(rootView: FileDrawerView(model: model, settings: settings))
        let handle = DrawerGrip()
        handle.setAccessibilityLabel(model.text("Resize file drawer", "调整抽屉宽度"))
        handle.resize = { [weak self] delta, finished in self?.resize(by: delta, finished: finished) }
        for view in [content as NSView, handle] {
            view.translatesAutoresizingMaskIntoConstraints = false
            backdrop.addSubview(view)
        }
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 7),
            content.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -7),
            content.topAnchor.constraint(equalTo: backdrop.topAnchor),
            content.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor),
            handle.widthAnchor.constraint(equalToConstant: 8),
            handle.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 16),
            handle.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -16)
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
        workspace.addObserver(self, selector: #selector(displayChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displayChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private var autoPreview: Bool?
    private func apply(_ value: FileDrawerPreferences) {
        guard let panel else { return }
        guard value.enabled else { panel.close(); return }
        if let background, let grip {
            edgeConstraint?.isActive = false
            edgeConstraint = value.side == .right ? grip.leadingAnchor.constraint(equalTo: background.leadingAnchor)
                : grip.trailingAnchor.constraint(equalTo: background.trailingAnchor)
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
        if panel.frame != rect {
            if !closing { background?.layer?.removeAnimation(forKey: Self.transitionKey) }
            panel.setFrame(rect, display: true)
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
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            background?.layer?.removeAnimation(forKey: Self.transitionKey)
            if closing { panel?.close(); return }
        }
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
        guard let panel, let layer = background?.layer else {
            if !opening { panel?.close() }
            return
        }
        let edge: CGFloat = settings.committedPreferences.fileDrawer.side == .right ? 8 : -8
        let targetOffset = opening ? 0 : edge
        let targetOpacity: Float = opening ? 1 : 0
        let current = layer.animation(forKey: Self.transitionKey) == nil ? nil : layer.presentation()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DMakeTranslation(targetOffset, 0, 0)
        layer.opacity = targetOpacity
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            layer.removeAnimation(forKey: Self.transitionKey)
            CATransaction.commit()
            if !opening { panel.close() }
            return
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = current?.opacity ?? (opening ? 0 : 1)
        fade.toValue = targetOpacity
        let shift = CABasicAnimation(keyPath: "transform.translation.x")
        shift.fromValue = current?.transform.m41 ?? (opening ? edge : 0)
        shift.toValue = targetOffset
        let group = CAAnimationGroup()
        group.duration = opening ? 0.16 : 0.12
        fade.duration = group.duration
        shift.duration = group.duration
        group.animations = [fade, shift]
        group.timingFunction = CAMediaTimingFunction(name: opening ? .easeOut : .easeIn)
        if let fps = display?.maximumFramesPerSecond, fps > 0 {
            let maximum = Float(fps)
            group.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, maximum), maximum: maximum, preferred: maximum)
        }
        if !opening {
            CATransaction.setCompletionBlock { [weak self, weak panel] in
                Task { @MainActor in
                    guard let self, self.panel === panel, self.closing, self.transitionID == id else { return }
                    panel?.close()
                }
            }
        }
        layer.add(group, forKey: Self.transitionKey)
        CATransaction.commit()
    }
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSPanel, closing === panel else { return }
        trackingMenus.removeAll()
        self.closing = false
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
        autoPreview = nil
        draggingWidth = false
    }
}

private final class DrawerBackground: NSView {
    private let effect = NSVisualEffectView()
    private let solid = NSBox()
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
        for view in [effect, solid] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
    }
    required init?(coder: NSCoder) { nil }
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
