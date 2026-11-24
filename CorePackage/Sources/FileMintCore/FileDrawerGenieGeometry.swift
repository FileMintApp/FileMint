import CoreGraphics

public struct FileDrawerGenieGeometry: Sendable {
    public let columns: Int
    public let rows: Int

    private let anchor: SIMD2<Float>
    private let landingScale: Float

    public init(size: CGSize, position: FileDrawerPreferences.Position) {
        let point = position.anchor
        anchor = SIMD2(Float(point.x), Float(point.y))
        // Sample more densely along the length of a funnel. Corners bend in both axes.
        if point.y == 0.5 {
            (columns, rows) = (32, 8)
        } else if point.x == 0.5 {
            (columns, rows) = (8, 32)
        } else {
            (columns, rows) = (16, 16)
        }
        landingScale = Float(min(1, 28 / max(1, size.width, size.height)))
    }

    public var outlineIndices: [Int] {
        let stride = columns + 1
        return Array(0...columns)
            + (1...rows).map { $0 * stride + columns }
            + (0..<columns).reversed().map { rows * stride + $0 }
            + (1..<rows).reversed().map { $0 * stride }
    }

    public func vertices(at progress: Float) -> [SIMD2<Float>] {
        let squeeze = Self.ease(from: 0, to: 0.4, at: progress)
        let pull = (1 - landingScale) * Self.ease(from: 1.0 / 3, to: 1, at: progress)
        if anchor.x != 0.5, anchor.y != 0.5 {
            let taper = (1 - landingScale) * squeeze * (1 - Self.ease(from: 0.74, to: 1, at: progress))
            return cornerVertices(taper: taper, scale: 1 - pull)
        }

        let horizontal = anchor.y == 0.5
        let positive = (horizontal ? anchor.x : anchor.y) == 1
        let length = horizontal ? columns : rows
        let sections = (0...length).map { index -> (along: Float, crossScale: Float) in
            let along = Float(index) / Float(length)
            let towardsEdge = positive ? along : 1 - along
            let shifted = towardsEdge + (1 - towardsEdge) * pull
            // Each section passes through the same curve between the miniature and the full-size free edge.
            let body = Self.ease(from: landingScale, to: 1, at: 1 - shifted)
            let crossScale = 1 - (1 - landingScale) * squeeze * (1 - body)
            return (positive ? shifted : 1 - shifted, crossScale)
        }

        var vertices: [SIMD2<Float>] = []
        vertices.reserveCapacity((columns + 1) * (rows + 1))
        for row in 0...rows {
            for column in 0...columns {
                let section = sections[horizontal ? column : row]
                let across = horizontal ? Float(row) / Float(rows) : Float(column) / Float(columns)
                let cross = 0.5 + (across - 0.5) * section.crossScale
                vertices.append(horizontal ? SIMD2(section.along, cross) : SIMD2(cross, section.along))
            }
        }
        return vertices
    }

    private func cornerVertices(taper: Float, scale: Float) -> [SIMD2<Float>] {
        let right = anchor.x == 1
        let top = anchor.y == 1
        var vertices: [SIMD2<Float>] = []
        vertices.reserveCapacity((columns + 1) * (rows + 1))
        for row in 0...rows {
            let y = Float(row) / Float(rows)
            let v = top ? 1 - y : y
            for column in 0...columns {
                let x = Float(column) / Float(columns)
                let u = right ? 1 - x : x
                let distance = (u + v) / 2
                // Pinch across the diagonal while preserving order along it. The far
                // half holds its shape at first and the taper releases into an equal scale.
                let mix = 0.5 * taper * (1 - Self.ease(from: 0, to: 0.5, at: distance))
                let dx = scale * (u + (v - u) * mix)
                let dy = scale * (v + (u - v) * mix)
                vertices.append(SIMD2(right ? 1 - dx : dx, top ? 1 - dy : dy))
            }
        }
        return vertices
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
