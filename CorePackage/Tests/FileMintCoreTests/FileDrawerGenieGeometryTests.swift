import CoreGraphics
import FileMintCore
import Testing

@Suite("Drawer Genie geometry")
struct FileDrawerGenieGeometryTests {
    @Test("the attached end narrows before the free end moves into the edge")
    func closesInTwoPhases() throws {
        let effect = FileDrawerGenieGeometry(size: CGSize(width: 500, height: 700), side: .right)
        let open = effect.vertices(at: 0)
        #expect(open.first == SIMD2(0, 0) && open.last == SIMD2(1, 1))
        let pinched = effect.vertices(at: 0.28)
        let free = try #require(pinched.first)
        let near = pinched[FileDrawerGenieGeometry.columns]
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
        let left = FileDrawerGenieGeometry(size: size, side: .left)
        let right = FileDrawerGenieGeometry(size: size, side: .right)
        let stride = FileDrawerGenieGeometry.columns + 1
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
                let top = FileDrawerGenieGeometry.rows * stride + column
                #expect(abs(r[top].y + r[column].y - 1) < 0.0001)
            }
        }
        let end = right.vertices(at: 1)
        let scaleX = CGFloat(1 - end[0].x)
        let scaleY = CGFloat(end[end.count - 1].y - end[stride - 1].y)
        #expect(abs(scaleX - scaleY) < 0.0001)
        #expect(abs(max(scaleX * size.width, scaleY * size.height) - 28) < 0.001)
    }
}
