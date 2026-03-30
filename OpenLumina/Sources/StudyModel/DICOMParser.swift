import Foundation

enum StudyCatalogError: LocalizedError {
    case noImagesFound(URL)
    case unsupportedTransferSyntax(String)
    case unsupportedImage(String)
    case malformedDICOM(String)

    var errorDescription: String? {
        switch self {
        case .noImagesFound(let url):
            return "No renderable DICOM images were found at \(url.lastPathComponent)."
        case .unsupportedTransferSyntax(let uid):
            return "Unsupported DICOM transfer syntax: \(uid)"
        case .unsupportedImage(let reason):
            return "Unsupported DICOM image: \(reason)"
        case .malformedDICOM(let reason):
            return "Malformed DICOM data: \(reason)"
        }
    }
}

struct DICOMElement {
    let tag: UInt32
    let vr: String?
    let value: Data
    let children: [DICOMElement]
}

struct DICOMDataSet {
    let transferSyntaxUID: String
    let elementsByTag: [UInt32: DICOMElement]

    func string(for tag: UInt32) -> String? {
        elementsByTag[tag].flatMap { data in
            String(data: data.value, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        }
    }

    func uint16(for tag: UInt32) -> UInt16? {
        guard let value = elementsByTag[tag]?.value, value.count >= 2 else { return nil }
        return value.withUnsafeBytes { $0.load(as: UInt16.self) }
    }

    func int16(for tag: UInt32) -> Int16? {
        guard let value = elementsByTag[tag]?.value, value.count >= 2 else { return nil }
        return value.withUnsafeBytes { $0.load(as: Int16.self) }
    }

    func data(for tag: UInt32) -> Data? {
        elementsByTag[tag]?.value
    }
}

struct DICOMParser {
    private static let explicitVRsUsing32BitLength: Set<String> = [
        "OB", "OD", "OF", "OL", "OV", "OW", "SQ", "UC", "UR", "UT", "UN"
    ]

    func parseFile(at url: URL) throws -> DICOMDataSet {
        let data = try Data(contentsOf: url)
        return try parseDataSet(from: data)
    }

    func parseDataSet(from data: Data) throws -> DICOMDataSet {
        let transferSyntax = detectTransferSyntax(in: data)
        let elementStart = data.count >= 132 && String(data: data.subdata(in: 128..<132), encoding: .ascii) == "DICM" ? 132 : 0
        let elements = try parseElements(in: data, offset: elementStart, explicitVR: transferSyntax.explicitVR)
        var map: [UInt32: DICOMElement] = [:]
        for element in elements {
            map[element.tag] = element
        }

        if transferSyntax.uid == nil {
            let metaElements = try parseElements(in: data, offset: elementStart, explicitVR: true, stopAtGroupChange: 0x0002)
            let metaMap = Dictionary(uniqueKeysWithValues: metaElements.map { ($0.tag, $0) })
            let uid = metaMap[0x00020010].flatMap {
                String(data: $0.value, encoding: .ascii)?
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
            } ?? TransferSyntax.explicitLittleEndian.rawValue
            return DICOMDataSet(transferSyntaxUID: uid, elementsByTag: map)
        }

        return DICOMDataSet(transferSyntaxUID: transferSyntax.uid!, elementsByTag: map)
    }

    func fileLooksLikeDICOM(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let prefix = try? handle.read(upToCount: 260)
        guard let prefix else { return false }
        if prefix.count >= 132 && String(data: prefix.subdata(in: 128..<132), encoding: .ascii) == "DICM" {
            return true
        }
        if prefix.count >= 8 {
            let group = UInt16(prefix[0]) | (UInt16(prefix[1]) << 8)
            return group == 0x0002 || group == 0x0008
        }
        return false
    }

    private func parseElements(
        in data: Data,
        offset: Int,
        explicitVR: Bool,
        stopAtGroupChange: UInt16? = nil,
        stopAtUndefinedItemDelimiter: Bool = false
    ) throws -> [DICOMElement] {
        var cursor = offset
        var elements: [DICOMElement] = []

        while cursor + 8 <= data.count {
            let group = data.uint16LE(at: cursor)
            let element = data.uint16LE(at: cursor + 2)
            let tag = (UInt32(group) << 16) | UInt32(element)

            if stopAtUndefinedItemDelimiter && tag == 0xFFFEE0DD {
                return elements
            }
            if stopAtUndefinedItemDelimiter && tag == 0xFFFEE00D {
                return elements
            }
            if let stopAtGroupChange, group != stopAtGroupChange {
                return elements
            }

            cursor += 4
            var vr: String?
            let valueLength: Int

            if explicitVR {
                vr = data.asciiString(in: cursor..<min(cursor + 2, data.count))
                cursor += 2
                if let vr, Self.explicitVRsUsing32BitLength.contains(vr) {
                    cursor += 2
                    valueLength = Int(data.uint32LE(at: cursor))
                    cursor += 4
                } else {
                    valueLength = Int(data.uint16LE(at: cursor))
                    cursor += 2
                }
            } else {
                valueLength = Int(data.uint32LE(at: cursor))
                cursor += 4
            }

            if valueLength == 0xFFFFFFFF {
                let childElements = try parseSequenceItems(
                    in: data,
                    offset: cursor,
                    explicitVR: explicitVR
                )
                let consumedLength = childElements.1
                elements.append(
                    DICOMElement(
                        tag: tag,
                        vr: vr,
                        value: Data(),
                        children: childElements.0
                    )
                )
                cursor += consumedLength
                continue
            }

            guard cursor + valueLength <= data.count else {
                throw StudyCatalogError.malformedDICOM("Element length overruns file bounds.")
            }

            let value = data.subdata(in: cursor..<(cursor + valueLength))
            let childElements: [DICOMElement]
            if vr == "SQ" {
                childElements = try parseSequenceItems(in: value, offset: 0, explicitVR: explicitVR).0
            } else {
                childElements = []
            }
            elements.append(DICOMElement(tag: tag, vr: vr, value: value, children: childElements))
            cursor += valueLength
        }

        return elements
    }

    private func parseSequenceItems(
        in data: Data,
        offset: Int,
        explicitVR: Bool
    ) throws -> ([DICOMElement], Int) {
        var cursor = offset
        var items: [DICOMElement] = []

        while cursor + 8 <= data.count {
            let tag = data.uint32LE(at: cursor)
            if tag == 0xFFFEE0DD {
                return (items, cursor + 8 - offset)
            }
            guard tag == 0xFFFEE000 else {
                break
            }

            let itemLength = Int(data.uint32LE(at: cursor + 4))
            cursor += 8

            let itemValueLength: Int
            let childData: Data
            if itemLength == 0xFFFFFFFF {
                let nested = try parseElements(
                    in: data,
                    offset: cursor,
                    explicitVR: explicitVR,
                    stopAtUndefinedItemDelimiter: true
                )
                let nestedBytes = lengthOf(elements: nested)
                itemValueLength = nestedBytes
                childData = data.subdata(in: cursor..<(cursor + nestedBytes))
                cursor += nestedBytes
                if cursor + 8 <= data.count && data.uint32LE(at: cursor) == 0xFFFEE00D {
                    cursor += 8
                }
                items.append(DICOMElement(tag: tag, vr: nil, value: childData, children: nested))
            } else {
                guard cursor + itemLength <= data.count else {
                    throw StudyCatalogError.malformedDICOM("Sequence item overruns file bounds.")
                }
                itemValueLength = itemLength
                childData = data.subdata(in: cursor..<(cursor + itemValueLength))
                let nested = try parseElements(in: childData, offset: 0, explicitVR: explicitVR)
                items.append(DICOMElement(tag: tag, vr: nil, value: childData, children: nested))
                cursor += itemValueLength
            }
        }

        return (items, cursor - offset)
    }

    private func lengthOf(elements: [DICOMElement]) -> Int {
        elements.reduce(0) { partial, element in
            let headerLength: Int
            if let vr = element.vr {
                headerLength = Self.explicitVRsUsing32BitLength.contains(vr) ? 12 : 8
            } else {
                headerLength = 8
            }
            return partial + headerLength + element.value.count
        }
    }

    private func detectTransferSyntax(in data: Data) -> (uid: String?, explicitVR: Bool) {
        guard data.count >= 132 else {
            return (TransferSyntax.explicitLittleEndian.rawValue, true)
        }
        let metaStart = String(data: data.subdata(in: 128..<132), encoding: .ascii) == "DICM" ? 132 : 0
        guard let metaElements = try? parseElements(in: data, offset: metaStart, explicitVR: true, stopAtGroupChange: 0x0002) else {
            return (TransferSyntax.explicitLittleEndian.rawValue, true)
        }
        let map = Dictionary(uniqueKeysWithValues: metaElements.map { ($0.tag, $0) })
        let uid = map[0x00020010].flatMap {
            String(data: $0.value, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        }
        let transferSyntax = TransferSyntax(rawValue: uid ?? TransferSyntax.explicitLittleEndian.rawValue) ?? .explicitLittleEndian
        return (uid ?? transferSyntax.rawValue, transferSyntax.explicitVR)
    }
}

enum TransferSyntax: String {
    case explicitLittleEndian = "1.2.840.10008.1.2.1"
    case implicitLittleEndian = "1.2.840.10008.1.2"

    var explicitVR: Bool {
        switch self {
        case .explicitLittleEndian:
            return true
        case .implicitLittleEndian:
            return false
        }
    }
}

private extension Data {
    func uint16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        let range = offset..<(offset + 2)
        return subdata(in: range).withUnsafeBytes { $0.load(as: UInt16.self) }
    }

    func uint32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        let range = offset..<(offset + 4)
        return subdata(in: range).withUnsafeBytes { $0.load(as: UInt32.self) }
    }

    func asciiString(in range: Range<Int>) -> String? {
        guard range.upperBound <= count else { return nil }
        return String(data: subdata(in: range), encoding: .ascii)
    }
}
