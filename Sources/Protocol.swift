import Foundation

// Wire protocol shared with the Windows host. See PROTOCOL.md. All integers are little-endian.
enum Proto {
    static let magic: UInt32 = 0x4E4D_5049   // bytes on the wire: 49 50 4D 4E
    static let version: UInt8 = 1
    static let port: UInt16 = 7878            // TCP port this app listens on (reached over USB)
    static let headerSize = 20
    static let maxPayload = 64 * 1024 * 1024

    enum Channel: UInt8 {
        case control = 0, video = 1, audio = 2, touch = 3, telemetry = 4
    }
    enum Control {
        static let hello: UInt16 = 1
        static let helloAck: UInt16 = 2
        static let settingsUpdate: UInt16 = 3
        static let ping: UInt16 = 4
        static let pong: UInt16 = 5
        static let bye: UInt16 = 6
    }
    enum Video {
        static let frameRawBgra: UInt16 = 1
    }
    enum Telemetry {
        static let deviceStatus: UInt16 = 1
    }
}

struct FeatureFlags: OptionSet {
    let rawValue: UInt16
    static let touch = FeatureFlags(rawValue: 1 << 0)
    static let audio = FeatureFlags(rawValue: 1 << 1)
    static let overlay = FeatureFlags(rawValue: 1 << 2)
}

struct ByteWriter {
    private(set) var data = Data()
    mutating func u8(_ v: UInt8) { data.append(v) }
    mutating func u16(_ v: UInt16) { u8(UInt8(v & 0xFF)); u8(UInt8(v >> 8)) }
    mutating func u32(_ v: UInt32) { u16(UInt16(v & 0xFFFF)); u16(UInt16(v >> 16)) }
    mutating func u64(_ v: UInt64) { u32(UInt32(v & 0xFFFF_FFFF)); u32(UInt32(v >> 32)) }
}

struct ByteReader {
    private let data: Data
    private var pos: Int
    private(set) var ok = true

    init(_ data: Data) {
        self.data = data
        self.pos = data.startIndex
    }
    mutating func u8() -> UInt8 {
        guard pos < data.endIndex else { ok = false; return 0 }
        let v = data[pos]
        pos += 1
        return v
    }
    mutating func u16() -> UInt16 { let a = UInt16(u8()); let b = UInt16(u8()); return a | (b << 8) }
    mutating func u32() -> UInt32 { let a = UInt32(u16()); let b = UInt32(u16()); return a | (b << 16) }
    mutating func u64() -> UInt64 { let a = UInt64(u32()); let b = UInt64(u32()); return a | (b << 32) }
    /// Everything not read yet (shares storage with the original Data).
    var remaining: Data { data[pos..<data.endIndex] }
}

struct FrameHeader {
    var channel: UInt8
    var type: UInt16
    var length: Int
    var ptsUs: UInt64
}

func makeFrame(channel: Proto.Channel, type: UInt16, ptsUs: UInt64 = 0, payload: Data = Data()) -> Data {
    var w = ByteWriter()
    w.u32(Proto.magic)
    w.u8(Proto.version)
    w.u8(channel.rawValue)
    w.u16(type)
    w.u32(UInt32(payload.count))
    w.u64(ptsUs)
    var out = w.data
    out.append(payload)
    return out
}

func parseHeader(_ data: Data) -> FrameHeader? {
    var r = ByteReader(data)
    guard r.u32() == Proto.magic, r.u8() == Proto.version else { return nil }
    let channel = r.u8()
    let type = r.u16()
    let length = Int(r.u32())
    let pts = r.u64()
    guard r.ok, length <= Proto.maxPayload else { return nil }
    return FrameHeader(channel: channel, type: type, length: length, ptsUs: pts)
}

/// Body of Hello (iPad -> PC) and HelloAck (PC -> iPad).
///   Hello:    width/height = screen in pixels, fps = max refresh rate, flags = this iPad's settings
///   HelloAck: width/height = stream size,      fps = stream rate,      flags = features effectively on
struct SessionParams {
    var width: Int
    var height: Int
    var fps: Int
    var flags: FeatureFlags

    func encoded() -> Data {
        var w = ByteWriter()
        w.u32(UInt32(Proto.version))
        w.u32(UInt32(width))
        w.u32(UInt32(height))
        w.u16(UInt16(clamping: fps))
        w.u16(flags.rawValue)
        return w.data
    }
}

extension SessionParams {
    init?(payload: Data) {
        var r = ByteReader(payload)
        let version = r.u32()
        let w = r.u32()
        let h = r.u32()
        let fps = r.u16()
        let flags = r.u16()
        guard r.ok, version == UInt32(Proto.version) else { return nil }
        self.init(width: Int(w), height: Int(h), fps: Int(fps), flags: FeatureFlags(rawValue: flags))
    }
}
