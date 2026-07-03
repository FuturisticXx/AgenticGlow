import AppKit
import Observation
import Symbols
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let symbolView = NSImageView()
    private var lastPresentation: StatusPresentation?

    init(
        model: AppModel,
        preferences: PreferencesStore,
        openIntegrations: @escaping () -> Void
    ) {
        self.model = model
        super.init()

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: SessionListView(
                model: model,
                preferences: preferences,
                openIntegrations: openIntegrations
            )
        )

        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.identifier = NSUserInterfaceItemIdentifier("AgenticGlow.StatusItem")
        item.button?.setAccessibilityIdentifier("AgenticGlow.StatusItem")
        if let button = item.button {
            symbolView.translatesAutoresizingMaskIntoConstraints = false
            symbolView.imageScaling = .scaleProportionallyDown
            button.addSubview(symbolView)
            NSLayoutConstraint.activate([
                symbolView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 3),
                symbolView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                symbolView.widthAnchor.constraint(equalToConstant: 18),
                symbolView.heightAnchor.constraint(equalToConstant: 18)
            ])
        }
        observeModel()
    }

    func stop() {
        symbolView.removeAllSymbolEffects()
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Task { await model.refreshUsage(.popoverOpened) }
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
        image?.isTemplate = true
        symbolView.image = image
        symbolView.contentTintColor = presentation.color
        item.button?.image = nil
        item.button?.title = presentation.title.isEmpty ? "" : "     \(presentation.title)"
        item.length = presentation.title.isEmpty ? 24 : NSStatusItem.variableLength
        item.button?.setAccessibilityLabel(presentation.accessibilityLabel)
        configureAnimation(enabled: presentation.animates)
    }

    private func configureAnimation(enabled: Bool) {
        symbolView.removeAllSymbolEffects()
        if enabled, #available(macOS 15.0, *) {
            let effect: RotateSymbolEffect = .rotate
            addIndefiniteEffect(
                effect,
                options: .repeating.speed(0.25)
            )
        }
    }

    private func addIndefiniteEffect<Effect>(
        _ effect: Effect,
        options: SymbolEffectOptions
    ) where Effect: IndefiniteSymbolEffect & SymbolEffect {
        symbolView.addSymbolEffect(effect, options: options)
    }
}
