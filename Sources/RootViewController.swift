import UIKit

/// Owns the link to the PC and swaps between the disconnected screen (with Settings) and the
/// connected screen (video only).
final class RootViewController: UIViewController, LinkServerDelegate {
    let link = LinkServer()
    private let videoView = VideoView()
    private let disconnectedVC = DisconnectedViewController()
    private var connectedVC: ConnectedViewController?
    private var current: UIViewController?

    override var childForStatusBarHidden: UIViewController? { current }
    override var childForHomeIndicatorAutoHidden: UIViewController? { current }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        show(disconnectedVC)
        link.delegate = self
        link.ensureListening()
    }

    private func show(_ new: UIViewController) {
        guard current !== new else { return }
        let old = current
        addChild(new)
        new.view.frame = view.bounds
        new.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(new.view)
        new.didMove(toParent: self)
        if let old = old {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        current = new
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    // MARK: LinkServerDelegate

    func linkDidConnect(_ params: SessionParams) {
        let vc = ConnectedViewController(videoView: videoView, link: link, flags: params.flags)
        let swapIn = { [weak self] in
            guard let self = self else { return }
            self.connectedVC = vc
            self.show(vc)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        // If Settings is open when the PC connects, close it first so it can't linger over the video.
        if let sheet = disconnectedVC.presentedViewController {
            sheet.dismiss(animated: false, completion: swapIn)
        } else {
            swapIn()
        }
    }

    func linkDidDisconnect() {
        connectedVC?.stop()
        connectedVC = nil
        videoView.reset()
        show(disconnectedVC)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func linkDidUpdateFlags(_ flags: FeatureFlags) {
        connectedVC?.apply(flags: flags)
    }

    func linkDidReceiveFrame(width: Int, height: Int, bgra: Data) {
        videoView.submit(width: width, height: height, bgra: bgra)
    }
}
