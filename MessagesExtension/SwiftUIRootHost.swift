import SwiftUI
import UIKit

final class SwiftUIRootHost {
    private weak var parent: UIViewController?
    private var hostingController: UIHostingController<AnyView>?

    init(parent: UIViewController) {
        self.parent = parent
    }

    func setRoot<Content: View>(_ view: Content) {
        let root = AnyView(view)

        if let hostingController {
            UIView.transition(with: hostingController.view, duration: 0.3,
                              options: [.transitionCrossDissolve, .allowUserInteraction]) {
                hostingController.rootView = root
            }
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
        controller.didMove(toParent: parent)
        hostingController = controller
    }
}
