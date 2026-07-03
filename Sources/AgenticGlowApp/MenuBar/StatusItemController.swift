import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var animationTimer: Timer?
    private var lastPresentation: StatusPresentation?

    init(model: AppModel, openIntegrations: @escaping () -> Void) {
        self.model = model
        super.init()

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: SessionListView(
                model: model,
                openIntegrations: openIntegrations
            )
        )

        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.identifier = NSUserInterfaceItemIdentifier("AgenticGlow.StatusItem")
        item.button?.setAccessibilityIdentifier("AgenticGlow.StatusItem")
        observeModel()
    }

    func stop() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func observeModel() {
        withObservationTracking {
            update()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeModel()
            }
        }
    }

    private func update() {
        let presentation = StatusPresentation(
            resolved: model.resolved,
            showTimer: model.showTimer,
            reduceMotion: model.reduceMotion
        )
        guard presentation != lastPresentation else { return }
        lastPresentation = presentation
        let image = NSImage(
            systemSymbolName: presentation.symbolName,
            accessibilityDescription: nil
        )
        image?.isTemplate = false
        item.button?.image = image
        item.button?.contentTintColor = presentation.color
        item.button?.title = presentation.title.isEmpty ? "" : " \(presentation.title)"
        item.button?.setAccessibilityLabel(presentation.accessibilityLabel)
        configureAnimation(enabled: presentation.animates)
    }

    private func configureAnimation(enabled: Bool) {
        guard enabled else {
            animationTimer?.invalidate()
            animationTimer = nil
            item.button?.alphaValue = 1
            return
        }
        guard animationTimer == nil else { return }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let button = self?.item.button else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    button.animator().alphaValue = button.alphaValue < 1 ? 1 : 0.55
                }
            }
        }
    }
}
