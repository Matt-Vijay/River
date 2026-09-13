import Messages
import Combine
import SwiftUI
import UIKit
import Poker
import RiverUI

final class MessagesViewController: MSMessagesAppViewController {
    @MainActor private struct Send {
        let update: TableMessage
        let message: MSMessage
        let url: URL
        let conversation: MSConversation
        let generation: Int
        let dismiss: Bool
    }

    private let session = RiverSession(isLocal: false)
    private let history = TableHistory()
    private var selected: MSMessage?
    private var conversationID: ObjectIdentifier?
    private var generation = 0
    private var pending: Send?
    private var joinAfterSend = false
    private var timeout: Task<Void, Never>?
    private var extensionIsActive = false
    private var hostIsActive = true
    private var hostObservers: [AnyCancellable] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        session.onEvent = { [weak self] in self?.handle($0) }
        let host = UIHostingController(rootView: RiverRoot(session: session, observesScenePhase: false))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        // Messages dismissal callbacks do not cover the host entering the app switcher.
        let center = NotificationCenter.default
        hostObservers = [Notification.Name.NSExtensionHostWillResignActive,
                         .NSExtensionHostDidEnterBackground, .NSExtensionHostDidBecomeActive].map { name in
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let contextID = (notification.object as? NSExtensionContext).map(ObjectIdentifier.init)
                let active = notification.name == .NSExtensionHostDidBecomeActive
                MainActor.assumeIsolated {
                    guard let self, let context = self.extensionContext,
                          contextID == ObjectIdentifier(context) else { return }
                    self.hostIsActive = active
                    self.updateVisibility()
                    if active { self.session.refreshProfile() }
                }
            }
            return AnyCancellable { center.removeObserver(observer) }
        }
    }

    private func updateVisibility() {
        session.isVisible = extensionIsActive && hostIsActive
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        extensionIsActive = false
        hostIsActive = true
        updateVisibility()
        session.refreshProfile()
        session.isCompact = presentationStyle == .compact
        configure(conversation)
        if let message = conversation.selectedMessage { open(message, in: conversation) }
        else {
            generation += 1
            joinAfterSend = false
            selected = nil
            session.surface = .invitation
        }
    }

    override func didBecomeActive(with conversation: MSConversation) {
        super.didBecomeActive(with: conversation)
        extensionIsActive = true
        updateVisibility()
        if session.profile == nil { requestPresentationStyle(.expanded) }
        joinOnOpening()
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        session.isCompact = presentationStyle == .compact
    }

    override func willResignActive(with conversation: MSConversation) {
        super.willResignActive(with: conversation)
        // A late send completion must not reopen or replace a dismissed interface.
        generation += 1
        joinAfterSend = false
        extensionIsActive = false
        updateVisibility()
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        configure(conversation)
        open(message, in: conversation)
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        guard activeConversation === conversation, let url = message.url else { return }
        if let send = pending, send.url == url, send.message.session == message.session {
            finish(send, error: nil)
            return
        }
        do {
            let update = try TableMessage(url: url)
            guard session.table?.id == update.table.id || history.latest(update.table.id) != nil else { return }
            let latest = try history.accept(update,
                sender: message.senderParticipantIdentifier.uuidString,
                localID: conversation.localParticipantIdentifier.uuidString)
            guard let previous = session.table, previous.id == update.table.id else { return }
            if selected?.session == message.session { selected = message }
            session.surface = .table(latest.table)
            showSeatLoss(from: previous, to: latest)
        } catch {
            // An unsolicited malformed update must not replace a valid table.
        }
    }

    private func configure(_ conversation: MSConversation) {
        let id = ObjectIdentifier(conversation)
        session.localID = conversation.localParticipantIdentifier.uuidString
        guard conversationID != id else { return }
        conversationID = id
        generation += 1
        joinAfterSend = false
        selected = nil
    }

    private func open(_ message: MSMessage, in conversation: MSConversation) {
        joinAfterSend = false
        session.error = nil
        if selected?.url != message.url || selected?.session != message.session { generation += 1 }
        selected = message
        requestPresentationStyle(.expanded)
        if let pending, pending.url == message.url, pending.message.session == message.session {
            finish(pending, error: nil)
        }
        do {
            guard let url = message.url else { throw TableError.invalidState }
            let update = try TableMessage(url: url)
            let latest = try history.accept(update,
                sender: message.senderParticipantIdentifier.uuidString,
                localID: conversation.localParticipantIdentifier.uuidString)
            if let pending, pending.update.table.id != latest.table.id { generation += 1 }
            session.surface = .table(latest.table)
            joinOnOpening()
        } catch { show(error, invalidMessage: true) }
    }

    private func joinOnOpening() {
        guard session.isVisible, let profile = session.profile, let table = session.table else { return }
        let latest = history.latest(table.id)?.table ?? table
        session.surface = .table(latest)
        joinAfterSend = false
        guard latest.canJoin(session.localID) else { return }
        guard pending == nil else { joinAfterSend = true; return }
        send(.join(profile), on: latest, replacing: selected, dismiss: false)
    }

    private func handle(_ event: RiverSession.Event) {
        switch event {
        case .profileSaved: joinOnOpening()
        case .newTable:
            guard let profile = session.profile else { return }
            send(.join(profile), on: Poker.Table(), replacing: nil, dismiss: true)
        case .action(let action):
            guard let table = session.table else { return }
            send(action, on: table, replacing: selected, dismiss: true)
        case .close:
            joinAfterSend = false
            dismiss()
        case .expand: requestPresentationStyle(.expanded)
        }
    }

    private func send(_ action: Action, on table: Poker.Table, replacing source: MSMessage?, dismiss: Bool) {
        guard pending == nil, let conversation = activeConversation else { return }
        do {
            if let latest = history.latest(table.id), latest.table != table {
                session.surface = .table(latest.table)
                throw TableError.stale
            }
            let update = try TableMessage(recording: action, on: table, actor: session.localID)
            let message = MSMessage(session: source?.session ?? MSSession())
            let url = try update.url()
            message.url = url
            guard message.url == url else { throw TableError.invalidState }
            message.summaryText = update.table.summary
            let layout = MSMessageTemplateLayout()
            let preview = MessagePreview(table: update.table)
            let renderer = ImageRenderer(content: preview
                .dynamicTypeSize(.large).frame(width: 320, height: 206))
            renderer.scale = 2
            layout.image = renderer.uiImage
            layout.caption = "Open table"
            message.layout = layout
            message.accessibilityLabel = preview.spokenDescription
            let send = Send(update: update, message: message, url: url, conversation: conversation,
                            generation: generation, dismiss: dismiss)
            pending = send
            session.isSending = true
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                self?.finish(send, error: URLError(.timedOut))
            }
            conversation.send(message) { [weak self] error in
                DispatchQueue.main.async { self?.finish(send, error: error) }
            }
        } catch TableError.expired {
            // Keep the table visible so its clock exposes the timeout action.
        } catch { show(error) }
    }

    private func finish(_ send: Send, error: Error?) {
        let isCurrent = pending?.message === send.message
        if isCurrent { clearSend() }
        defer {
            if isCurrent && joinAfterSend {
                joinAfterSend = false
                // Only resume a deferred opening, never retry this send's own opening.
                if generation != send.generation { joinOnOpening() }
            }
        }
        do {
            if let error { throw error }
            // Late confirmations can refresh the open table without retargeting its message.
            let newest = try history.accept(send.update,
                sender: send.conversation.localParticipantIdentifier.uuidString,
                localID: send.conversation.localParticipantIdentifier.uuidString)
            guard generation == send.generation, activeConversation === send.conversation else { return }
            guard isCurrent else {
                if session.table?.id == newest.table.id { session.surface = .table(newest.table) }
                return
            }
            selected = send.message
            session.surface = .table(newest.table)
            showSeatLoss(from: send.update.table, to: newest)
            let hasLocalTurn = newest.table.hand?.isComplete == false
                && newest.table.hand?.turn == session.localID
            if session.isVisible && send.dismiss && newest.fingerprint == send.update.fingerprint && !hasLocalTurn { dismiss() }
        } catch {
            guard isCurrent, generation == send.generation, activeConversation === send.conversation else { return }
            if let newer = history.latest(send.update.table.id), newer.isNewer(than: send.update) {
                session.surface = .table(newer.table)
                showSeatLoss(from: send.update.table, to: newer)
            } else { show(error) }
        }
    }

    private func showSeatLoss(from previous: Poker.Table, to latest: TableMessage) {
        let seat = latest.table.seat(session.localID)
        let lostRebuy = previous.hand?.isComplete == true && latest.table.hand?.isComplete == true
            && previous.hand?.number == latest.table.hand?.number && seat?.chips == 0
        guard previous.id == latest.table.id,
              previous.seat(session.localID)?.isEligible == true,
              seat == nil || seat?.hasLeft == true || lostRebuy,
              !(latest.move.actor == session.localID && latest.move.action == .leave) else { return }
        joinAfterSend = false
        session.error = latest.table.canJoin(session.localID)
            ? "Your seat was not kept. Close and reopen the table to join."
            : (latest.table.isFinished ? TableError.finished : .tableFull).localizedDescription
    }

    private func clearSend() {
        timeout?.cancel()
        timeout = nil
        pending = nil
        session.isSending = false
    }

    private func show(_ error: Error, invalidMessage: Bool = false) {
        let reason = (error as? TableError)?.localizedDescription
            ?? (invalidMessage ? TableError.invalidState.localizedDescription
                : "The update could not be confirmed. Check the conversation before trying again.")
        if invalidMessage { session.surface = .unavailable(reason) }
        else { session.error = reason }
    }
}
