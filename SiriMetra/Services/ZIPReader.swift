import Foundation
import Compression

/// Minimal ZIP archive reader using Apple's Compression framework.
/// Handles stored (method 0) and deflated (method 8) entries.
/// No third-party dependencies required.
enum ZIPReader {

    struct Entry {
        let filename: String
        let data: Data
    }

    enum ZIPError: LocalizedError {
        case invalidArchive
        case unsupportedCompression(method: UInt16)
        case decompressionFailed(filename: String)
        case truncatedEntry(filename: String)

        var errorDescription: String? {
            switch self {
            case .invalidArchive: return "Not a valid ZIP archive."
            case .unsupportedCompression(let m): return "Unsupported compression method \(m)."
            case .decompressionFailed(let f): return "Failed to decompress '\(f)'."
            case .truncatedEntry(let f): return "Truncated entry '\(f)'."
            }
        }
    }

    /// Extract all entries from a ZIP archive in memory.
    static func extract(from data: Data) throws -> [Entry] {
        var entries: [Entry] = []
        var offset = 0

        while offset + 30 <= data.count {
            // Read local file header signature (PK\x03\x04)
            let sig = data.readUInt32LE(at: offset)
            guard sig == 0x04034B50 else { break }

            let compressionMethod = data.readUInt16LE(at: offset + 8)
            let compressedSize = Int(data.readUInt32LE(at: offset + 18))
            let uncompressedSize = Int(data.readUInt32LE(at: offset + 22))
            let filenameLength = Int(data.readUInt16LE(at: offset + 26))
            let extraFieldLength = Int(data.readUInt16LE(at: offset + 28))

            let headerEnd = offset + 30
            let filenameEnd = headerEnd + filenameLength
            let dataStart = filenameEnd + extraFieldLength
            let dataEnd = dataStart + compressedSize

            guard filenameEnd <= data.count else { break }
            guard dataEnd <= data.count else { break }

            let filename = String(
                data: data[headerEnd..<filenameEnd],
                encoding: .utf8
            ) ?? ""

            // Skip directories
            guard !filename.hasSuffix("/") else {
                offset = dataEnd
                continue
            }

            let compressedData = data[dataStart..<dataEnd]

            let fileData: Data
            switch compressionMethod {
            case 0:
                // Stored — no compression
                fileData = Data(compressedData)
            case 8:
                // Deflate — use Compression framework's streaming decoder
                guard let decompressed = inflate(
                    Data(compressedData),
                    expectedSize: uncompressedSize
                ) else {
                    throw ZIPError.decompressionFailed(filename: filename)
                }
                fileData = decompressed
            default:
                throw ZIPError.unsupportedCompression(method: compressionMethod)
            }

            entries.append(Entry(filename: filename, data: fileData))
            offset = dataEnd
        }

        return entries
    }

    /// Decompress raw deflate data using the Compression framework's streaming API.
    /// The COMPRESSION_ZLIB decoder auto-detects raw deflate (RFC 1951).
    private static func inflate(_ compressedData: Data, expectedSize: Int) -> Data? {
        let bufferSize = max(expectedSize, 65536)
        var decompressed = Data()

        return compressedData.withUnsafeBytes { rawBuffer -> Data? in
            guard let sourcePtr = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }
            let sourceSize = rawBuffer.count

            let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
            defer { streamPtr.deallocate() }

            let status = compression_stream_init(
                streamPtr, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB
            )
            guard status != COMPRESSION_STATUS_ERROR else { return nil }
            defer { compression_stream_destroy(streamPtr) }

            streamPtr.pointee.src_ptr = sourcePtr
            streamPtr.pointee.src_size = sourceSize

            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { dstBuffer.deallocate() }

            var processStatus: compression_status
            repeat {
                streamPtr.pointee.dst_ptr = dstBuffer
                streamPtr.pointee.dst_size = bufferSize

                processStatus = compression_stream_process(
                    streamPtr,
                    Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
                )

                let outputSize = bufferSize - streamPtr.pointee.dst_size
                if outputSize > 0 {
                    decompressed.append(dstBuffer, count: outputSize)
                }
            } while processStatus == COMPRESSION_STATUS_OK

            guard processStatus == COMPRESSION_STATUS_END else { return nil }
            return decompressed
        }
    }
}

// MARK: - Data Extensions for Little-Endian Reads

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return self.withUnsafeBytes { buffer in
            let ptr = buffer.baseAddress!.advanced(by: offset)
                .assumingMemoryBound(to: UInt8.self)
            return UInt16(ptr[0]) | (UInt16(ptr[1]) << 8)
        }
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return self.withUnsafeBytes { buffer in
            let ptr = buffer.baseAddress!.advanced(by: offset)
                .assumingMemoryBound(to: UInt8.self)
            return UInt32(ptr[0])
                | (UInt32(ptr[1]) << 8)
                | (UInt32(ptr[2]) << 16)
                | (UInt32(ptr[3]) << 24)
        }
    }
}
