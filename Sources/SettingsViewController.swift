import UIKit

/// Presented only from the disconnected screen. Changes are saved immediately and sent to the PC
/// the next time a connection starts.
final class SettingsViewController: UIViewController {
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

        let touch = makeRow("Touch input", "Send touches on this screen to the PC.", AppSettings.touchEnabled) {
            AppSettings.touchEnabled = $0
        }
        let audio = makeRow("Audio", "Play the PC's sound on this iPad.", AppSettings.audioEnabled) {
            AppSettings.audioEnabled = $0
        }
        let overlay = makeRow("Battery and FPS overlay", "Show them in the top-left corner while connected.", AppSettings.overlayEnabled) {
            AppSettings.overlayEnabled = $0
        }

        let footer = UILabel()
        footer.text = "The settings remain available while connected, and are accessible by double tapping in the top-right corner. The PC host can also switch each feature off."
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

    private func makeRow(_ title: String, _ detail: String, _ isOn: Bool, _ onChange: @escaping (Bool) -> Void) -> UIView {
        let t = UILabel()
        t.text = title
        t.textColor = .white
        t.font = .systemFont(ofSize: 17, weight: .semibold)
        let d = UILabel()
        d.text = detail
        d.textColor = .lightGray
        d.font = .systemFont(ofSize: 13)
        d.numberOfLines = 0
        let labels = UIStackView(arrangedSubviews: [t, d])
        labels.axis = .vertical
        labels.spacing = 2

        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.addAction(UIAction { [weak toggle] _ in onChange(toggle?.isOn ?? false) }, for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [labels, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        return row
    }
}
