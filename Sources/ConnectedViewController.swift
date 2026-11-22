import UIKit


final class ConnectedViewController: UIViewController {
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    private let videoView: VideoView
    private let link: LinkServer
    private var flags: FeatureFlags
    private let overlay = PaddedLabel()
    private let config = UIButton(type: .system)
    private var timer: Timer?
    private var frameCount = 0

    init(videoView: VideoView, link: LinkServer, flags: FeatureFlags) {
        self.videoView = videoView
        self.link = link
        self.flags = flags
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        let activationArea = CGRect(
            x: view.bounds.maxX - 120,
            y: view.safeAreaInsets.top,
            width: 120,
            height: 120
        )
        
        guard activationArea.contains(point) else { return }
        config.isHidden.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.config.isHidden.toggle()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        

        
        videoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoView)
        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        overlay.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        overlay.textColor = .white
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        overlay.layer.cornerRadius = 8
        overlay.clipsToBounds = true
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isUserInteractionEnabled = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            overlay.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
        ])

        apply(flags: flags)
        videoView.onFrameDrawn = { [weak self] in self?.frameCount += 1 }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        tick()
        let doubleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDoubleTap(_:))
            )
        
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        
        config.setTitle("Settings", for: .normal)
        config.setTitleColor(.white, for: .normal)
        config.contentEdgeInsets = UIEdgeInsets(
            top: 10,
            left: 20,
            bottom: 10,
            right: 20
        )
        config.backgroundColor = .darkGray
        config.layer.cornerRadius = 14
        config.isHidden = true
        config.addTarget(self, action: #selector(ConnectedViewController.openSettings), for: .touchUpInside)
        
        config.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(config)

        NSLayoutConstraint.activate([
            config.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            config.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

    }
    
    @objc private func openSettings() {
        let vc = SettingsViewController()
        vc.modalPresentationStyle = .pageSheet
        present(vc, animated: true)
    }

    /// Called when the PC switches features on or off while connected.
    func apply(flags: FeatureFlags) {
        self.flags = flags
        overlay.isHidden = !flags.contains(.overlay)
    }

    /// Called by the root controller just before this screen is removed.
    func stop() {
        timer?.invalidate()
        timer = nil
        videoView.onFrameDrawn = nil
        videoView.removeFromSuperview()
    }

    private func tick() {
        let fps = frameCount
        frameCount = 0
        let device = UIDevice.current
        let level = device.batteryLevel
        let percent = level < 0 ? 255 : Int((level * 100).rounded())
        let charging = device.batteryState == .charging || device.batteryState == .full
        let batteryText = percent == 255 ? "--" : "\(percent)%"
        overlay.text = "\(fps) FPS  ·  \(charging ? "⚡︎ " : "")\(batteryText)"
        link.sendTelemetry(battery: percent, charging: charging, fps: fps)
    }
    

    
}

final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right, height: s.height + insets.top + insets.bottom)
    }
}
