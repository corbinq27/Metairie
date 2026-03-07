import Foundation
import Compression

/// Minimal ZIP archive reader using Apple's Compression framework.
/// Handles stored (method 0) and deflated (method 8) entries.
/// Supports ZIP files with data descriptors (flag bit 0x0008) by reading
/// the Central Directory for actual file sizes.
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
        case centralDirectoryNotFound

        var errorDescription: String? {
            switch self {
            case .invalidArchive: return "Not a valid ZIP archive."
            case .unsupportedCompression(let m): return "Unsupported compression method \(m)."
            case .decompressionFailed(let f): return "Failed to decompress '\(f)'."
            case .truncatedEntry(let f): return "Truncated entry '\(f)'."
            case .centralDirectoryNotFound: return "Cannot find ZIP central directory."
            }
        }
    }

    /// Central Directory entry info parsed from the end of the ZIP.
    private struct CDEntry {
        let filename: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    /// Extract all entries from a ZIP archive in memory.
    static func extract(from data: Data) throws -> [Entry] {
        // Parse the Central Directory to get accurate sizes
        let cdEntries = try parseCentralDirectory(data)
        var entries: [Entry] = []

        for cd in cdEntries {
            // Skip directories
            guard !cd.filename.hasSuffix("/") else { continue }

            // Read local file header to find where data actually starts
            let localOffset = cd.localHeaderOffset
            guard localOffset + 30 <= data.count else {
                throw ZIPError.truncatedEntry(filename: cd.filename)
            }
            let sig = data.readUInt32LE(at: localOffset)
            guard sig == 0x04034B50 else {
                throw ZIPError.invalidArchive
            }

            let filenameLength = Int(data.readUInt16LE(at: localOffset + 26))
            let extraFieldLength = Int(data.readUInt16LE(at: localOffset + 28))
            let dataStart = localOffset + 30 + filenameLength + extraFieldLength
            let dataEnd = dataStart + cd.compressedSize

            guard dataEnd <= data.count else {
                throw ZIPError.truncatedEntry(filename: cd.filename)
            }

            let compressedData = data[dataStart..<dataEnd]

            let fileData: Data
            switch cd.compressionMethod {
            case 0:
                // Stored — no compression
                fileData = Data(compressedData)
            case 8:
                // Deflate
                guard let decompressed = inflate(
                    Data(compressedData),
                    expectedSize: cd.uncompressedSize
                ) else {
                    throw ZIPError.decompressionFailed(filename: cd.filename)
                }
                fileData = decompressed
            default:
                throw ZIPError.unsupportedCompression(method: cd.compressionMethod)
            }

            entries.append(Entry(filename: cd.filename, data: fileData))
        }

        return entries
    }

    /// Find and parse the End of Central Directory record, then read all
    /// Central Directory file headers to get accurate sizes.
    private static func parseCentralDirectory(_ data: Data) throws -> [CDEntry] {
        // Find End of Central Directory record (signature 0x06054B50)
        // Search backwards from end of file (EOCD is at least 22 bytes)
        let eocdSig: UInt32 = 0x06054B50
        var eocdOffset = -1

        // EOCD can have a variable-length comment, so scan backwards
        let searchStart = max(0, data.count - 65557) // max comment = 65535
        for i in stride(from: data.count - 22, through: searchStart, by: -1) {
            if data.readUInt32LE(at: i) == eocdSig {
                eocdOffset = i
                break
            }
        }

        guard eocdOffset >= 0 else {
            throw ZIPError.centralDirectoryNotFound
        }

        let cdSize = Int(data.readUInt32LE(at: eocdOffset + 12))
        let cdOffset = Int(data.readUInt32LE(at: eocdOffset + 16))
        let totalEntries = Int(data.readUInt16LE(at: eocdOffset + 10))

        guard cdOffset + cdSize <= data.count else {
            throw ZIPError.invalidArchive
        }

        // Parse Central Directory file headers (signature 0x02014B50)
        var entries: [CDEntry] = []
        var offset = cdOffset

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count else { break }
            let sig = data.readUInt32LE(at: offset)
            guard sig == 0x02014B50 else { break }

            let compressionMethod = data.readUInt16LE(at: offset + 10)
            let compressedSize = Int(data.readUInt32LE(at: offset + 20))
            let uncompressedSize = Int(data.readUInt32LE(at: offset + 24))
            let filenameLength = Int(data.readUInt16LE(at: offset + 28))
            let extraFieldLength = Int(data.readUInt16LE(at: offset + 30))
            let commentLength = Int(data.readUInt16LE(at: offset + 32))
            let localHeaderOffset = Int(data.readUInt32LE(at: offset + 42))

            let fnStart = offset + 46
            let fnEnd = fnStart + filenameLength
            guard fnEnd <= data.count else { break }

            let filename = String(
                data: data[fnStart..<fnEnd],
                encoding: .utf8
            ) ?? ""

            entries.append(CDEntry(
                filename: filename,
                compressionMethod: compressionMethod,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            ))

            offset = fnEnd + extraFieldLength + commentLength
        }

        return entries
    }

    /// Decompress raw deflate data using the Compression framework's streaming API.
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
