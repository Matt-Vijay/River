import SwiftUI
import UIKit

final class SwiftUIRootHost {
    enum Interruption {
        case profile
        case recovery
    }

    private struct RootIdentity: Hashable {
        let key: String
        let scope: Int
    }

    private weak var parent: UIViewController?
    private var hostingController: UIHostingController<AnyView>?
    private let sendingIndicator = UIActivityIndicatorView(style: .medium)
    private var identityScope = 0
    private(set) var interruption: Interruption?

    var isProfile: Bool { interruption == .profile }
    var isRecovery: Bool { interruption == .recovery }
    var allowsAutomaticRendering: Bool { interruption == nil }

    init(parent: UIViewController) {
        self.parent = parent
    }

    func setRoot<Content: View>(_ view: Content, identity: String,
                                interruption: Interruption? = nil) {
        self.interruption = interruption
        let root = AnyView(view.id(RootIdentity(key: identity, scope: identityScope)))
        if let hostingController {
            hostingController.rootView = root
            return
        }

        guard let parent else { return }
        let controller = UIHostingController(rootView: root)
        parent.addChild(controller)

        guard let child = controller.view else {
            controller.removeFromParent()
            return
        }

        child.translatesAutoresizingMaskIntoConstraints = false
        child.backgroundColor = .black
        parent.view.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
            child.topAnchor.constraint(equalTo: parent.view.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.view.bottomAnchor),
        ])
        sendingIndicator.translatesAutoresizingMaskIntoConstraints = false
        sendingIndicator.color = .white
        sendingIndicator.hidesWhenStopped = true
        sendingIndicator.isAccessibilityElement = false
        parent.view.addSubview(sendingIndicator)
        NSLayoutConstraint.activate([
            sendingIndicator.centerXAnchor.constraint(equalTo: parent.view.centerXAnchor),
            sendingIndicator.centerYAnchor.constraint(equalTo: parent.view.centerYAnchor),
        ])
        controller.didMove(toParent: parent)
        hostingController = controller
    }

    func invalidateIdentity() {
        identityScope &+= 1
    }

    func resumeAutomaticRendering() {
        interruption = nil
    }

    func setInteractionEnabled(_ isEnabled: Bool) {
        guard let view = hostingController?.view else { return }
        view.isUserInteractionEnabled = isEnabled
        view.alpha = isEnabled ? 1 : 0.65
        if isEnabled {
            sendingIndicator.stopAnimating()
        } else {
            sendingIndicator.startAnimating()
            UIAccessibility.post(notification: .announcement, argument: "Sending update")
        }
    }

}
