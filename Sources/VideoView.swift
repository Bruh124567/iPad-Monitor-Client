import MetalKit
import UIKit

/// Draws the newest received frame, letterboxed to keep the aspect ratio. Frames can be submitted from
/// any thread; if frames arrive faster than the screen can draw them, older ones are dropped.
final class VideoView: MTKView {
    /// Called on the main thread each time a frame has been drawn (used for the FPS counter).
    var onFrameDrawn: (() -> Void)?

    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var texture: MTLTexture?
    private let lock = NSLock()
    private var pending: (width: Int, height: Int, data: Data)?
    private var drawScheduled = false

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VOut { float4 position [[position]]; float2 uv; };
    vertex VOut vs(uint vid [[vertex_id]]) {
        const float2 p[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
        const float2 t[4] = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
        VOut o;
        o.position = float4(p[vid], 0, 1);
        o.uv = t[vid];
        return o;
    }
    fragment float4 fs(VOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        return tex.sample(s, in.uv);
    }
    """

    init() {
        guard let dev = MTLCreateSystemDefaultDevice(), let queue = dev.makeCommandQueue() else {
            fatalError("Metal is not available on this device")
        }
        do {
            let library = try dev.makeLibrary(source: VideoView.shaderSource, options: nil)
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = library.makeFunction(name: "vs")
            desc.fragmentFunction = library.makeFunction(name: "fs")
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeline = try dev.makeRenderPipelineState(descriptor: desc)
        } catch {
            fatalError("Metal pipeline setup failed: \(error)")
        }
        commandQueue = queue
        super.init(frame: .zero, device: dev)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        isPaused = true                  // we draw only when a new frame arrives
        enableSetNeedsDisplay = false
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        isOpaque = true
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Thread-safe. `data` must hold width * height * 4 bytes of BGRA pixels.
    func submit(width: Int, height: Int, bgra: Data) {
        lock.lock()
        pending = (width, height, bgra)
        let needsDraw = !drawScheduled
        drawScheduled = true
        lock.unlock()
        if needsDraw {
            DispatchQueue.main.async { [weak self] in self?.draw() }
        }
    }

    /// Main thread. Forgets the last picture so the next connection starts from black.
    func reset() {
        lock.lock()
        pending = nil
        lock.unlock()
        texture = nil
    }

    override func draw(_ rect: CGRect) {
        lock.lock()
        let frame = pending
        pending = nil
        drawScheduled = false
        lock.unlock()
        if let frame = frame { upload(frame.width, frame.height, frame.data) }

        guard let tex = texture,
              let drawable = currentDrawable,
              let pass = currentRenderPassDescriptor,
              let cmd = commandQueue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }

        let dw = Double(drawableSize.width), dh = Double(drawableSize.height)
        let scale = min(dw / Double(tex.width), dh / Double(tex.height))
        let w = Double(tex.width) * scale, h = Double(tex.height) * scale
        enc.setViewport(MTLViewport(originX: (dw - w) / 2, originY: (dh - h) / 2, width: w, height: h, znear: 0, zfar: 1))
        enc.setRenderPipelineState(pipeline)
        enc.setFragmentTexture(tex, index: 0)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
        onFrameDrawn?()
    }

    private func upload(_ width: Int, _ height: Int, _ data: Data) {
        if texture == nil || texture!.width != width || texture!.height != height {
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            desc.usage = .shaderRead
            texture = device?.makeTexture(descriptor: desc)
        }
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            texture?.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                             withBytes: base, bytesPerRow: width * 4)
        }
    }
}
