import CoreGraphics

public struct FileDrawerGenieGeometry: Sendable {
    public static let columns = 32
    public static let rows = 8

    private let side: FileDrawerPreferences.Side
    private let landingScale: Float

    public init(size: CGSize, side: FileDrawerPreferences.Side) {
        self.side = side
        // The miniature fits within 28 points on either edge and retains the window's aspect ratio.
        landingScale = Float(min(1, 28 / max(1, size.width, size.height)))
    }

    public func vertices(at progress: Float) -> [SIMD2<Float>] {
        let squeeze = Self.ease(from: 0, to: 0.4, at: progress)
        let pull = (1 - landingScale) * Self.ease(from: 1.0 / 3, to: 1, at: progress)
        let columns = (0...Self.columns).map { column -> (x: Float, height: Float) in
            let x = Float(column) / Float(Self.columns)
            let towardsEdge = side == .right ? x : 1 - x
            let shifted = towardsEdge + (1 - towardsEdge) * pull
            // Each column travels through the same curve between the miniature and the full-height free edge.
            let body = Self.ease(from: landingScale, to: 1, at: 1 - shifted)
            let height = 1 - (1 - landingScale) * squeeze * (1 - body)
            return (side == .right ? shifted : 1 - shifted, height)
        }
        return (0...Self.rows).flatMap { row in
            let y = Float(row) / Float(Self.rows) - 0.5
            return columns.map { SIMD2($0.x, 0.5 + y * $0.height) }
        }
    }

    public func opacity(at progress: Float) -> Float {
        1 - Self.ease(from: 0.82, to: 1, at: progress)
    }

    private static func ease(from start: Float, to end: Float, at value: Float) -> Float {
        guard end > start else { return 0 }
        let t = min(1, max(0, (value - start) / (end - start)))
        return (1 - cos(.pi * t)) * 0.5
    }
}
