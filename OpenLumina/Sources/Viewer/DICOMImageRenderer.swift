import CoreGraphics
import Foundation

protocol ImageRendering {
    func renderImage(at url: URL) throws -> CGImage
}

struct DICOMImageRenderer: ImageRendering {
    private let parser = DICOMParser()

    func renderImage(at url: URL) throws -> CGImage {
        let dataSet = try parser.parseFile(at: url)

        guard
            let transferSyntax = TransferSyntax(rawValue: dataSet.transferSyntaxUID)
        else {
            throw StudyCatalogError.unsupportedTransferSyntax(dataSet.transferSyntaxUID)
        }

        guard transferSyntax == .explicitLittleEndian || transferSyntax == .implicitLittleEndian else {
            throw StudyCatalogError.unsupportedTransferSyntax(transferSyntax.rawValue)
        }

        guard
            let rows = dataSet.uint16(for: 0x00280010),
            let columns = dataSet.uint16(for: 0x00280011),
            let bitsAllocated = dataSet.uint16(for: 0x00280100),
            let samplesPerPixel = dataSet.uint16(for: 0x00280002),
            let pixelData = dataSet.data(for: 0x7FE00010)
        else {
            throw StudyCatalogError.unsupportedImage("Missing required pixel data attributes.")
        }

        guard samplesPerPixel == 1 else {
            throw StudyCatalogError.unsupportedImage("Only grayscale images are supported in the first build.")
        }

        guard bitsAllocated == 8 || bitsAllocated == 16 else {
            throw StudyCatalogError.unsupportedImage("Only 8-bit or 16-bit grayscale images are supported.")
        }

        let photometricInterpretation = dataSet.string(for: 0x00280004) ?? "MONOCHROME2"
        let pixelRepresentation = dataSet.uint16(for: 0x00280103) ?? 0
        let bitsStored = dataSet.uint16(for: 0x00280101) ?? bitsAllocated
        let imageBytes = try normalizePixelData(
            pixelData,
            rows: Int(rows),
            columns: Int(columns),
            bitsAllocated: Int(bitsAllocated),
            bitsStored: Int(bitsStored),
            photometricInterpretation: photometricInterpretation,
            signedPixels: pixelRepresentation == 1
        )

        guard
            let provider = CGDataProvider(data: imageBytes as CFData),
            let cgImage = CGImage(
                width: Int(columns),
                height: Int(rows),
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: Int(columns),
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            throw StudyCatalogError.unsupportedImage("Unable to construct a renderable image.")
        }

        return cgImage
    }

    private func normalizePixelData(
        _ data: Data,
        rows: Int,
        columns: Int,
        bitsAllocated: Int,
        bitsStored: Int,
        photometricInterpretation: String,
        signedPixels: Bool
    ) throws -> Data {
        let pixelCount = rows * columns
        if bitsAllocated == 8 {
            guard data.count >= pixelCount else {
                throw StudyCatalogError.unsupportedImage("Pixel payload is smaller than expected.")
            }
            var bytes = Array(data.prefix(pixelCount))
            if photometricInterpretation == "MONOCHROME1" {
                bytes = bytes.map { 255 &- $0 }
            }
            return Data(bytes)
        }

        let expectedBytes = pixelCount * 2
        guard data.count >= expectedBytes else {
            throw StudyCatalogError.unsupportedImage("16-bit pixel payload is smaller than expected.")
        }

        let mask = UInt16((1 << bitsStored) - 1)
        var values: [UInt16] = stride(from: 0, to: expectedBytes, by: 2).map { offset in
            data.subdata(in: offset..<(offset + 2)).withUnsafeBytes { $0.load(as: UInt16.self) }
        }

        let minValue: Int
        let maxValue: Int
        let intValues: [Int]

        if signedPixels {
            let shift = 16 - bitsStored
            intValues = values.map { raw in
                Int(Int16(bitPattern: raw << shift) >> shift)
            }
            minValue = intValues.min() ?? 0
            maxValue = intValues.max() ?? 1
        } else {
            values = values.map { $0 & mask }
            intValues = values.map(Int.init)
            minValue = 0
            maxValue = intValues.max() ?? 1
        }

        let range = max(1, maxValue - minValue)
        let normalized = intValues.map { sample -> UInt8 in
            let scalar = Double(sample - minValue) / Double(range)
            let mapped = UInt8(max(0, min(255, Int(round(scalar * 255.0)))))
            return photometricInterpretation == "MONOCHROME1" ? (255 &- mapped) : mapped
        }

        return Data(normalized)
    }
}
