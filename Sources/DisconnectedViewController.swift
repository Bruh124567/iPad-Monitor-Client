import UIKit

/// Shown whenever the PC is not connected. This is the only screen with a Settings button.
final class DisconnectedViewController: UIViewController {
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        overrideUserInterfaceStyle = .dark

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()

        let title = UILabel()
        title.text = "Waiting for your PC"
        title.font = .systemFont(ofSize: 30, weight: .bold)
        title.textColor = .white

        let hint = UILabel()
        hint.text = "Connect this iPad to the PC with a USB cable and start the iPad Monitor host."
        hint.font = .systemFont(ofSize: 17)
        hint.textColor = .lightGray
        hint.textAlignment = .center
        hint.numberOfLines = 0

        var config = UIButton.Configuration.gray()
        config.title = "Settings"
        config.image = UIImage(systemName: "gearshape")
        config.imagePadding = 8
        config.cornerStyle = .capsule
        let settings = UIButton(configuration: config)
        settings.addAction(UIAction { [weak self] _ in self?.openSettings() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [spinner, title, hint, settings])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 18
        stack.setCustomSpacing(32, after: hint)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            hint.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
        ])
    }

    private func openSettings() {
        let vc = SettingsViewController()
        vc.modalPresentationStyle = .pageSheet
        present(vc, animated: true)
    }
}
