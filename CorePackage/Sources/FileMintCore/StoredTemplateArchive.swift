import Foundation
import zlib

/// V1's deliberately small stored-only container. No extraction or generic ZIP API.
enum StoredTemplateArchive {
    static func crc(_ bytes: Data) -> UInt32 {
        UInt32(bytes.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(bytes.count)) })
    }
    static func encode(_ entries: [(String, Data)]) throws -> Data {
        guard (1...101).contains(entries.count), Set(entries.map(\.0)).count == entries.count else { throw TemplatePackageError.invalid }
        var output = Data(), central = Data()
        func append(_ number: Int, count: Int, to data: inout Data) {
            for index in 0..<count { data.append(UInt8(truncatingIfNeeded: number >> (index * 8))) }
        }
        for (name, bytes) in entries {
            let nameData = Data(name.utf8), offset = output.count, checksum = Int(crc(bytes))
            guard nameData.count <= 256, bytes.count <= TemplatePackageCodec.maximumBytes,
                  output.count <= TemplatePackageCodec.maximumBytes - bytes.count - 30 - nameData.count else { throw TemplatePackageError.tooLarge }
            for (value, count) in [(0x04034b50,4),(20,2),(0x800,2),(0,2),(0,2),(0,2),(checksum,4),(bytes.count,4),(bytes.count,4),(nameData.count,2),(0,2)] {
                append(value, count: count, to: &output)
            }
            output.append(nameData); output.append(bytes)
            for (value, count) in [(0x02014b50,4),(0x314,2),(20,2),(0x800,2),(0,2),(0,2),(0,2),(checksum,4),(bytes.count,4),(bytes.count,4),(nameData.count,2),(0,2),(0,2),(0,2),(0,2),(0o100600 << 16,4),(offset,4)] {
                append(value, count: count, to: &central)
            }
            central.append(nameData)
        }
        let start = output.count
        output.append(central)
        for (value, count) in [(0x06054b50,4),(0,2),(0,2),(entries.count,2),(entries.count,2),(central.count,4),(start,4),(0,2)] {
            append(value, count: count, to: &output)
        }
        guard output.count <= TemplatePackageCodec.maximumBytes else { throw TemplatePackageError.tooLarge }
        return output
    }
    static func decode(_ data: Data) throws -> [String: Data] {
        guard data.count <= TemplatePackageCodec.maximumBytes else { throw TemplatePackageError.tooLarge }
        guard data.count >= 22 else { throw TemplatePackageError.invalid }
        func number(_ offset: Int, _ length: Int) throws -> Int {
            guard offset >= 0, length <= data.count, offset <= data.count - length else { throw TemplatePackageError.invalid }
            return (0..<length).reduce(0) { $0 | Int(data[offset + $1]) << ($1 * 8) }
        }
        let footer = data.count - 22
        guard try number(footer,4) == 0x06054b50, try number(footer+4,2) == 0,
              try number(footer+6,2) == 0, try number(footer+20,2) == 0 else { throw TemplatePackageError.invalid }
        let count = try number(footer+10,2), start = try number(footer+16,4), length = try number(footer+12,4)
        guard (1...101).contains(count) else { throw TemplatePackageError.tooLarge }
        guard try number(footer+8,2) == count, start <= footer, length == footer - start else { throw TemplatePackageError.invalid }
        var cursor = start, result: [String: Data] = [:], ranges: [Range<Int>] = [], total = 0
        for _ in 0..<count {
            guard cursor <= footer-46, try number(cursor,4) == 0x02014b50 else { throw TemplatePackageError.invalid }
            let flags = try number(cursor+8,2), size = try number(cursor+24,4), nameLength = try number(cursor+28,2)
            let offset = try number(cursor+42,4), checksum = try number(cursor+16,4), attributes = try number(cursor+38,4)
            let mode = (attributes >> 16) & 0xf000
            guard try number(cursor+6,2) <= 20, [0,0x800].contains(flags), try number(cursor+10,2) == 0,
                  try number(cursor+20,4) == size, try number(cursor+30,2) == 0, try number(cursor+32,2) == 0,
                  try number(cursor+34,2) == 0, [0,0x8000].contains(mode), attributes & 0x10 == 0,
                  (1...256).contains(nameLength), nameLength <= footer-cursor-46,
                  offset <= start-30 else { throw TemplatePackageError.invalid }
            guard let name = String(data: data.subdata(in: cursor+46..<cursor+46+nameLength), encoding: .utf8),
                  !name.hasPrefix("/"), !name.hasSuffix("/"), !name.contains("\\"), !name.contains(":"),
                  !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
                  !name.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
                  result[name] == nil else { throw TemplatePackageError.invalid }
            guard try number(offset,4) == 0x04034b50, try number(offset+4,2) <= 20,
                  try number(offset+6,2) == flags, try number(offset+8,2) == 0,
                  try number(offset+10,2) == number(cursor+12,2), try number(offset+12,2) == number(cursor+14,2),
                  try number(offset+14,4) == checksum, try number(offset+18,4) == size,
                  try number(offset+22,4) == size, try number(offset+26,2) == nameLength,
                  try number(offset+28,2) == 0 else { throw TemplatePackageError.invalid }
            let body = offset+30+nameLength
            guard body <= start, size <= start-body, total <= TemplatePackageCodec.maximumBytes-size,
                  data.subdata(in: offset+30..<body) == Data(name.utf8) else { throw TemplatePackageError.invalid }
            if name == "manifest.json", size > TemplatePackageCodec.maximumManifestBytes { throw TemplatePackageError.tooLarge }
            let bytes = data.subdata(in: body..<body+size)
            guard crc(bytes) == UInt32(checksum) else { throw TemplatePackageError.invalid }
            total += size; ranges.append(offset..<body+size); result[name] = bytes
            cursor += 46+nameLength
        }
        guard cursor == footer else { throw TemplatePackageError.invalid }
        var end = 0
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            guard range.lowerBound == end else { throw TemplatePackageError.invalid }
            end = range.upperBound
        }
        guard end == start else { throw TemplatePackageError.invalid }
        return result
    }
}
