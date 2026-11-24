import AppKit
import FileMintCore
import MetalKit
import SpriteKit

@MainActor
final class FileDrawerGenieTransition: MTKView {
    typealias BackdropUpdate = @MainActor ([SIMD2<Float>], CGFloat) -> Void

    private struct Motion {
        let id = UUID()
        let from: Float
        let to: Float
        let duration: TimeInterval
        let completion: @MainActor () -> Void
        var firstFrame: TimeInterval?
    }

    private let renderer: SKRenderer
    private let queue: any MTLCommandQueue
    private let sprite: SKSpriteNode
    private let geometry: FileDrawerGenieGeometry
    private let outlineIndices: [Int]
    private let updateBackdrop: BackdropUpdate?
    private var motion: Motion?
    private var completionTask: Task<Void, Never>?
    private(set) var progress: Float
    var restoredOpeningImage: (@MainActor () -> CGImage?)?
    // The signed fixture samples the actual display presentation times.
    var framePresented: (@Sendable (TimeInterval) -> Void)?

    init?(image: CGImage, frame: CGRect, position: FileDrawerPreferences.Position, opening: Bool, framesPerSecond: Int,
          updateBackdrop: BackdropUpdate?) {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        self.queue = queue
        renderer = SKRenderer(device: device)
        sprite = SKSpriteNode(texture: SKTexture(cgImage: image), size: frame.size)
        let geometry = FileDrawerGenieGeometry(size: frame.size, position: position)
        self.geometry = geometry
        outlineIndices = geometry.outlineIndices
        self.updateBackdrop = updateBackdrop
        progress = opening ? 1 : 0
        super.init(frame: frame, device: device)
        isPaused = true
        presentsWithTransaction = updateBackdrop != nil
        layer?.isOpaque = false
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        if framesPerSecond > 0 { preferredFramesPerSecond = framesPerSecond }
        let scene = SKScene(size: frame.size)
        scene.backgroundColor = .clear
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.subdivisionLevels = 0
        scene.addChild(sprite)
        renderer.scene = scene
        deform(at: progress)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("Use the drawer transition initializer") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func play(opening: Bool, completion: @escaping @MainActor () -> Void) {
        let end: Float = opening ? 0 : 1
        let duration = 0.5 * Double(abs(end - progress))
        guard duration > 0 else { completion(); return }
        motion = Motion(from: progress, to: end, duration: duration, completion: completion)
        finishIfOccluded(after: duration)
        isPaused = false
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let motion, let pass = currentRenderPassDescriptor, let drawable = currentDrawable,
              let buffer = queue.makeCommandBuffer() else { return }
        if let framePresented {
            drawable.addPresentedHandler { framePresented($0.presentedTime) }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if motion.to == 0, let image = restoredOpeningImage?() {
            sprite.texture = SKTexture(cgImage: image)
            restoredOpeningImage = nil
        }
        if let firstFrame = motion.firstFrame {
            let amount = Float(min(1, (CACurrentMediaTime() - firstFrame) / motion.duration))
            deform(at: amount == 1 ? motion.to : motion.from + (motion.to - motion.from) * amount)
            if amount == 1 {
                isPaused = true
                drawable.addPresentedHandler { [weak self, id = motion.id] _ in
                    Task { @MainActor in
                        guard let self, self.motion?.id == id else { return }
                        self.finishMotion()
                    }
                }
            }
        }
        renderFrame(to: pass, using: buffer)
        if presentsWithTransaction {
            // Present the controls in the same transaction as the material's outline.
            buffer.commit()
            buffer.waitUntilScheduled()
            drawable.present()
        } else {
            buffer.present(drawable)
            buffer.commit()
        }
        CATransaction.commit()
        if motion.firstFrame == nil {
            self.motion?.firstFrame = CACurrentMediaTime()
            finishIfOccluded(after: motion.duration)
        }
    }

    func renderFrame(to pass: MTLRenderPassDescriptor, using buffer: any MTLCommandBuffer) {
        guard let texture = pass.colorAttachments[0].texture else { return }
        renderer.update(atTime: CACurrentMediaTime())
        let viewport = CGRect(x: 0, y: 0, width: texture.width, height: texture.height)
        renderer.render(withViewport: viewport, commandBuffer: buffer, renderPassDescriptor: pass)
    }

    func discard() {
        completionTask?.cancel()
        motion = nil
        isPaused = true
        removeFromSuperview()
    }

    private func finishMotion() {
        let completion = motion?.completion
        motion = nil
        isPaused = true
        completionTask?.cancel()
        completionTask = nil
        completion?()
    }

    private func finishIfOccluded(after duration: TimeInterval) {
        completionTask?.cancel()
        completionTask = Task { [weak self] in
            // An occluded window may stop delivering draw or presentation callbacks.
            try? await Task.sleep(for: .seconds(duration + 0.35))
            guard !Task.isCancelled else { return }
            self?.finishMotion()
        }
    }

    private func deform(at progress: Float) {
        self.progress = progress
        let opacity = CGFloat(geometry.opacity(at: progress))
        let vertices = geometry.vertices(at: progress)
        sprite.alpha = opacity
        sprite.warpGeometry = SKWarpGeometryGrid(columns: geometry.columns, rows: geometry.rows,
                                                  destinationPositions: vertices)
        if let updateBackdrop { updateBackdrop(outlineIndices.map { vertices[$0] }, opacity) }
    }
}
