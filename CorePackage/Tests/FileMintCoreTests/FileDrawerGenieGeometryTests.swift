import CoreGraphics
import FileMintCore
import Testing

@Suite("Drawer Genie geometry")
struct FileDrawerGenieGeometryTests {
    @Test("the attached end narrows before the free end moves into the edge")
    func closesInTwoPhases() throws {
        let effect = FileDrawerGenieGeometry(size: CGSize(width: 500, height: 700), position: .right)
        let open = effect.vertices(at: 0)
        #expect(open.first == SIMD2(0, 0) && open.last == SIMD2(1, 1))
        let pinched = effect.vertices(at: 0.28)
        let free = try #require(pinched.first)
        let near = pinched[effect.columns]
        #expect(free == SIMD2(0, 0))
        #expect(near.x == 1 && near.y > 0.25)
        #expect(effect.opacity(at: 0.7) == 1)

        let closed = effect.vertices(at: 1)
        let first = try #require(closed.first)
        let last = try #require(closed.last)
        #expect(abs(first.x - 0.96) < 0.0001 && abs(first.y - 0.48) < 0.0001)
        #expect(last.x == 1 && abs(last.y - 0.52) < 0.0001)
        #expect(effect.opacity(at: 1) == 0)
    }

    @Test("each panel size follows a centered, unfolded curve into the same edge target", arguments: [
        CGSize(width: 240, height: 1_100), CGSize(width: 517.5, height: 683.5), CGSize(width: 2_000, height: 480)
    ])
    func mirrorsAcrossPanel(size: CGSize) {
        let left = FileDrawerGenieGeometry(size: size, position: .left)
        let right = FileDrawerGenieGeometry(size: size, position: .right)
        let stride = right.columns + 1
        for step in 0...20 {
            let progress = Float(step) / 20
            let l = left.vertices(at: progress)
            let r = right.vertices(at: progress)
            for index in r.indices {
                let column = index % stride
                let mirror = (index / stride + 1) * stride - 1 - column
                #expect(abs(l[mirror].x + r[index].x - 1) < 0.0001)
                #expect(abs(l[mirror].y - r[index].y) < 0.0001)
                #expect((0...1).contains(r[index].x) && (0...1).contains(r[index].y))
                if column > 0 { #expect(r[index].x > r[index - 1].x) }
                if index >= stride { #expect(r[index].y > r[index - stride].y) }
            }
            for column in 0..<stride {
                let top = right.rows * stride + column
                #expect(abs(r[top].y + r[column].y - 1) < 0.0001)
            }
        }
        let end = right.vertices(at: 1)
        let scaleX = CGFloat(1 - end[0].x)
        let scaleY = CGFloat(end[end.count - 1].y - end[stride - 1].y)
        #expect(abs(scaleX - scaleY) < 0.0001)
        #expect(abs(max(scaleX * size.width, scaleY * size.height) - 28) < 0.001)
    }

    @Test("vertical and corner tapers start at the anchor with the far body still in place")
    func earlyTaper() {
        let size = CGSize(width: 640, height: 900)
        let top = FileDrawerGenieGeometry(size: size, position: .top)
        let vertical = top.vertices(at: 0.28)
        let topRow = top.rows * (top.columns + 1)
        #expect(vertical.first == SIMD2(0, 0))
        #expect(vertical[topRow].x > 0.25 && vertical[topRow].y == 1)
        #expect(vertical[topRow + top.columns / 2] == SIMD2(0.5, 1))

        let corner = FileDrawerGenieGeometry(size: size, position: .topRight)
        let diagonal = corner.vertices(at: 0.28)
        let pinched = diagonal[diagonal.count - 1 - corner.columns / 4]
        #expect(diagonal.first == SIMD2(0, 0) && diagonal.last == SIMD2(1, 1))
        #expect(pinched.x > 0.75 && pinched.y < 1)
        let afterPull = corner.vertices(at: 0.55)
        #expect(afterPull[0].x > 0 && afterPull[0].y > 0)
    }

    @Test("every mesh stays upright and inside its window and lands at its selected anchor",
          arguments: FileDrawerPreferences.Position.allCases,
          [CGSize(width: 240, height: 1_100), CGSize(width: 517.5, height: 683.5), CGSize(width: 2_000, height: 480)])
    func mesh(position: FileDrawerPreferences.Position, size: CGSize) {
        let geometry = FileDrawerGenieGeometry(size: size, position: position)
        let stride = geometry.columns + 1
        let outline = geometry.outlineIndices
        #expect(Set(outline).count == 2 * (geometry.rows + geometry.columns))
        let nextOutlineIndices = outline.dropFirst() + outline.prefix(1)
        let outlineIsContinuous = zip(outline, nextOutlineIndices).allSatisfy { current, next in
            let columnDistance = abs(current % stride - next % stride)
            let rowDistance = abs(current / stride - next / stride)
            return columnDistance + rowDistance == 1
        }
        #expect(outlineIsContinuous)

        let anchor = SIMD2(Float(position.anchor.x), Float(position.anchor.y))
        let landing = Float(28 / max(size.width, size.height))
        let start = geometry.vertices(at: 0)
        let end = geometry.vertices(at: 1)
        #expect(start.indices.allSatisfy { index in
            let source = SIMD2(Float(index % stride) / Float(geometry.columns), Float(index / stride) / Float(geometry.rows))
            let target = anchor + (source - anchor) * landing
            return start[index] == source && abs(end[index].x - target.x) < 0.0001 && abs(end[index].y - target.y) < 0.0001
        })
        #expect(geometry.opacity(at: 0) == 1 && geometry.opacity(at: 1) == 0)

        func turn(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float {
            let u = b - a, v = c - b
            return u.x * v.y - u.y * v.x
        }
        for step in 0...32 {
            let points = geometry.vertices(at: Float(step) / 32)
            #expect(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
            let anchorIndex = Int(anchor.y * Float(geometry.rows)) * stride + Int(anchor.x * Float(geometry.columns))
            #expect(points[anchorIndex] == anchor)
            let upright = (0..<geometry.rows).allSatisfy { row in
                (0..<geometry.columns).allSatisfy { column in
                    let index = row * stride + column
                    let a = points[index], b = points[index + 1]
                    let c = points[index + stride + 1], d = points[index + stride]
                    return turn(a, b, c) > 0 && turn(b, c, d) > 0 && turn(c, d, a) > 0 && turn(d, a, b) > 0
                }
            }
            #expect(upright, "Mesh folded at step \(step)")
        }
    }
}
