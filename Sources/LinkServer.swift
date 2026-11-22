import Foundation
import Network
import UIKit

/// Delegate callbacks for connect, disconnect and settings run on the main queue.
/// `linkDidReceiveFrame` runs on the network queue (VideoView.submit is thread-safe).
protocol LinkServerDelegate: AnyObject {
    func linkDidConnect(_ params: SessionParams)
    func linkDidDisconnect()
    func linkDidUpdateFlags(_ flags: FeatureFlags)
    func linkDidReceiveFrame(width: Int, height: Int, bgra: Data)
}

/// Listens on a local TCP port. The PC reaches that port through the USB cable (usbmuxd), so no
/// Wi-Fi or network permissions are involved. One PC connection at a time; a new one replaces the old.
final class LinkServer {
    weak var delegate: LinkServerDelegate?

    private let queue = DispatchQueue(label: "ipadmonitor.link")
    private var listener: NWListener?
    private var connection: NWConnection?
    private var generation = 0        // identifies the current connection; stale callbacks are ignored
    private var established = false   // true once the PC has acknowledged our Hello

    // MARK: Lifecycle

    func ensureListening() {
        queue.async { [weak self] in
            guard let self = self, self.listener == nil else { return }
            self.startListener()
        }
    }

    private func startListener() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            guard let port = NWEndpoint.Port(rawValue: Proto.port) else { return }
            let l = try NWListener(using: params, on: port)
            l.newConnectionHandler = { [weak self] c in self?.accept(c) }
            l.stateUpdateHandler = { [weak self, weak l] state in
                switch state {
                case .failed, .cancelled:
                    self?.queue.async {
                        if self?.listener === l { self?.listener = nil }
                    }
                    self?.queue.asyncAfter(deadline: .now() + 2) { self?.ensureListening() }
                default:
                    break
                }
            }
            listener = l
            l.start(queue: queue)
        } catch {
            queue.asyncAfter(deadline: .now() + 2) { [weak self] in self?.ensureListening() }
        }
    }

    // MARK: Connections

    private func accept(_ c: NWConnection) {
        if let old = connection {
            connection = nil
            old.cancel()
            if established { established = false; notifyDisconnected() }
        }
        generation += 1
        let gen = generation
        connection = c
        established = false
        c.stateUpdateHandler = { [weak self] state in
            guard let self = self, self.generation == gen else { return }
            switch state {
            case .ready:
                self.sendHello(on: c)
                self.readHeader(c, gen)
            case .failed, .cancelled:
                self.closed(gen)
            default:
                break
            }
        }
        c.start(queue: queue)
    }

    private func closed(_ gen: Int) {
        guard gen == generation else { return }
        connection = nil
        if established {
            established = false
            notifyDisconnected()
        }
    }

    private func drop(_ c: NWConnection, _ gen: Int) {
        c.cancel()
        closed(gen)
    }

    private func notifyDisconnected() {
        DispatchQueue.main.async { [weak self] in self?.delegate?.linkDidDisconnect() }
    }

    // MARK: Reading

    private func readHeader(_ c: NWConnection, _ gen: Int) {
        c.receive(minimumIncompleteLength: Proto.headerSize, maximumLength: Proto.headerSize) { [weak self] data, _, _, error in
            guard let self = self, self.generation == gen else { return }
            guard error == nil, let data = data, data.count == Proto.headerSize, let header = parseHeader(data) else {
                self.drop(c, gen)
                return
            }
            if header.length == 0 {
                self.handle(header, Data(), c)
                self.readHeader(c, gen)
                return
            }
            c.receive(minimumIncompleteLength: header.length, maximumLength: header.length) { [weak self] payload, _, _, error in
                guard let self = self, self.generation == gen else { return }
                guard error == nil, let payload = payload, payload.count == header.length else {
                    self.drop(c, gen)
                    return
                }
                self.handle(header, payload, c)
                self.readHeader(c, gen)
            }
        }
    }

    private func handle(_ h: FrameHeader, _ payload: Data, _ c: NWConnection) {
        guard let channel = Proto.Channel(rawValue: h.channel) else { return }
        switch channel {
        case .control:
            switch h.type {
            case Proto.Control.helloAck:
                guard !established, let params = SessionParams(payload: payload) else { return }
                established = true
                DispatchQueue.main.async { [weak self] in self?.delegate?.linkDidConnect(params) }
            case Proto.Control.settingsUpdate:
                var r = ByteReader(payload)
                let flags = FeatureFlags(rawValue: r.u16())
                guard r.ok else { return }
                DispatchQueue.main.async { [weak self] in self?.delegate?.linkDidUpdateFlags(flags) }
            case Proto.Control.ping:
                write(c, .control, Proto.Control.pong, ptsUs: h.ptsUs, payload: payload)
            case Proto.Control.bye:
                drop(c, generation)
            default:
                break
            }
        case .video:
            guard established, h.type == Proto.Video.frameRawBgra else { return }
            var r = ByteReader(payload)
            let w = Int(r.u32()), height = Int(r.u32()), stride = Int(r.u32())
            let pixels = r.remaining
            guard r.ok, w > 0, height > 0, stride == w * 4, pixels.count == stride * height else { return }
            delegate?.linkDidReceiveFrame(width: w, height: height, bgra: pixels)
        case .audio, .touch, .telemetry:
            break   // audio and touch arrive in later steps
        }
    }

    // MARK: Writing

    private func sendHello(on c: NWConnection) {
        let px = UIScreen.main.nativeBounds.size
        let params = SessionParams(
            width: Int(max(px.width, px.height)),
            height: Int(min(px.width, px.height)),
            fps: UIScreen.main.maximumFramesPerSecond,
            flags: AppSettings.flags)
        write(c, .control, Proto.Control.hello, payload: params.encoded())
    }

    private func write(_ c: NWConnection, _ channel: Proto.Channel, _ type: UInt16, ptsUs: UInt64 = 0, payload: Data = Data()) {
        c.send(content: makeFrame(channel: channel, type: type, ptsUs: ptsUs, payload: payload),
               completion: .contentProcessed { _ in })
    }

    /// Sends the current feature settings to the connected host.
    func sendSettingsUpdate(_ flags: FeatureFlags) {
        var writer = ByteWriter()
        writer.u16(flags.rawValue)
        let payload = writer.data
        queue.async { [weak self] in
            guard let self, self.established, let connection = self.connection else { return }
            self.write(connection, .control, Proto.Control.settingsUpdate, payload: payload)
        }
    }

    /// Battery 0-100 (255 = unknown), charging flag, and frames per second actually drawn.
    func sendTelemetry(battery: Int, charging: Bool, fps: Int) {
        var w = ByteWriter()
        w.u8(UInt8(clamping: battery))
        w.u8(charging ? 1 : 0)
        w.u16(UInt16(clamping: fps))
        let payload = w.data
        queue.async { [weak self] in
            guard let self = self, self.established, let c = self.connection else { return }
            self.write(c, .telemetry, Proto.Telemetry.deviceStatus, payload: payload)
        }
    }
}
