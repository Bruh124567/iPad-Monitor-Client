import UIKit

/// Lets the user change the iPad's feature settings. Changes are saved immediately.
final class SettingsViewController: UIViewController {
    private let onSettingsChanged: (FeatureFlags) -> Void
    private var toggles: [FeatureFlags: UISwitch] = [:]

    init(onSettingsChanged: @escaping (FeatureFlags) -> Void = { _ in }) {
        self.onSettingsChanged = onSettingsChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(white: 0.1, alpha: 1)

        let title = UILabel()
        title.text = "Settings"
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.textColor = .white

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        done.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [title, UIView(), done])
        header.axis = .horizontal
        header.alignment = .center

        let touch = makeRow("Touch input", "Send touches on this screen to the PC.", flag: .touch)
        let audio = makeRow("Audio", "Play the PC's sound on this iPad.", flag: .audio)
        let overlay = makeRow("Battery and FPS overlay", "Show them in the top-left corner while connected.", flag: .overlay)

        let footer = UILabel()
        footer.text = "Changes apply immediately while connected. The PC host can also update each feature."
        footer.font = .systemFont(ofSize: 13)
        footer.textColor = .gray
        footer.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [header, touch, audio, overlay, footer])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
        ])
    }

    /// Applies a settings update received from the connected host without sending it back.
    func apply(flags: FeatureFlags) {
        AppSettings.apply(flags: flags)
        for (flag, toggle) in toggles {
            toggle.setOn(flags.contains(flag), animated: viewIfLoaded?.window != nil)
        }
    }

    private func makeRow(_ title: String, _ detail: String, flag: FeatureFlags) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.textColor = .lightGray
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.numberOfLines = 0

        let labels = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        labels.axis = .vertical
        labels.spacing = 2

        let toggle = UISwitch()
        toggle.isOn = AppSettings.flags.contains(flag)
        toggles[flag] = toggle
        toggle.addAction(UIAction { [weak self, weak toggle] _ in
            guard let self, let toggle else { return }
            self.set(flag: flag, enabled: toggle.isOn)
        }, for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [labels, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        return row
    }

    private func set(flag: FeatureFlags, enabled: Bool) {
        var flags = AppSettings.flags
        if enabled {
            flags.insert(flag)
        } else {
            flags.remove(flag)
        }
        apply(flags: flags)
        onSettingsChanged(flags)
    }
}
