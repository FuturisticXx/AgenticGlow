import AppKit
import AgenticGlowCore
import Observation
import Symbols
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let symbolView = NSImageView()
    private let badgeView = NSView()
    private let popoverState = PopoverState()
    private var lastPresentation: StatusPresentation?
    private var lastCelebrationCount = 0
    private var celebrationResetTask: Task<Void, Never>?
    private var motionTask: Task<Void, Never>?
    private var motionRotating = false
    /// Providers coloring the animated icon; two entries cross-fade, one is a
    /// solid provider tint. The frame task resolves actual colors per frame
    /// against the bar's current appearance, so a wallpaper that flips the
    /// bar light or dark re-palettes the icon within a frame, no observers.
    private var motionProviders: [AgentProvider]?
    private var currentSymbolName: String?
    private var currentSolidColor: NSColor?

    /// Menu bar motion is ambient, not feedback: it plays for minutes at a time
    /// while an agent works. Slow and continuous reads as calm; anything brisk
    /// enough to notice becomes a distraction in the corner of the eye.
    ///
    /// Rotation is driven by our own frame task, not RotateSymbolEffect: the
    /// cross-fade must swap the symbol image every frame (the menu bar flattens
    /// contentTintColor, so color has to be baked in), and every image swap
    /// restarts a symbol effect, which stuttered the spin.
    private enum Motion {
        /// Seconds per full revolution. The hexagon grid repeats every 60
        /// degrees, so the visible pattern cycles once every period/6 seconds.
        static let rotationPeriod: Double = 12.0
        /// Seconds for one direction of the blue <-> orange sweep.
        static let crossfadePeriod: Double = 5.0
        /// The sweep tops out at this much orange instead of saturating.
        static let crossfadePeakShare: Double = 0.8
        /// 30fps. At the previous 0.06s the sweep banded into visible steps.
        static let frameInterval: Double = 1.0 / 30.0
    }

    init(
        model: AppModel,
        preferences: PreferencesStore,
        claudeCredentialStore: any ClaudeSessionCredentialStoring,
        openIntegrations: @escaping () -> Void
    ) {
        self.model = model
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: SessionListView(
                model: model,
                preferences: preferences,
                popoverState: popoverState,
                claudeCredentialStore: claudeCredentialStore,
                openIntegrations: openIntegrations,
                settingsPresentationChanged: { [weak self] isPresented in
                    self?.setSettingsPresented(isPresented)
                }
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
            badgeView.translatesAutoresizingMaskIntoConstraints = false
            badgeView.wantsLayer = true
            badgeView.layer?.cornerRadius = 3
            badgeView.isHidden = true
            button.addSubview(badgeView)
            NSLayoutConstraint.activate([
                symbolView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 3),
                symbolView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                symbolView.widthAnchor.constraint(equalToConstant: 18),
                symbolView.heightAnchor.constraint(equalToConstant: 18),
                badgeView.trailingAnchor.constraint(equalTo: symbolView.trailingAnchor, constant: 1),
                badgeView.topAnchor.constraint(equalTo: symbolView.topAnchor, constant: -1),
                badgeView.widthAnchor.constraint(equalToConstant: 6),
                badgeView.heightAnchor.constraint(equalToConstant: 6)
            ])
        }
        observeModel()
    }

    func stop() {
        motionTask?.cancel()
        motionTask = nil
        symbolView.removeAllSymbolEffects()
    }

    func popoverDidClose(_ notification: Notification) {
        popoverState.isPresented = false
    }

    func showPopoverForVisualQA() {
        guard !popover.isShown else { return }
        togglePopover()
    }

    func setSettingsPresented(_ isPresented: Bool) {
        popover.behavior = isPresented ? .applicationDefined : .transient
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            popoverState.isPresented = false
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popoverState.isPresented = true
            Task { await model.refreshUsage(.popoverOpened) }
            Task { await model.refreshServiceStatus() }
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
            reduceMotion: model.reduceMotion,
            lowAllowance: model.hasLowAllowance
        )
        let celebrating = beginCelebrationIfNeeded(symbolName: presentation.symbolName)
        guard presentation != lastPresentation else { return }
        lastPresentation = presentation
        applyTint(presentation, celebrating: celebrating)
        badgeView.isHidden = !presentation.showsAllowanceBadge
        badgeView.layer?.backgroundColor = NSColor.systemOrange.cgColor
        item.button?.image = nil
        item.button?.title = presentation.title.isEmpty ? "" : "     \(presentation.title)"
        item.length = presentation.title.isEmpty ? 24 : NSStatusItem.variableLength
        item.button?.setAccessibilityLabel(presentation.accessibilityLabel)
        configureAnimation(enabled: presentation.animates)
        reconcileMotionTask()
    }

    /// Briefly turns the icon green (with a bounce where available) when a
    /// weekly allowance window rolls over, then restores the live state.
    private func beginCelebrationIfNeeded(symbolName: String) -> Bool {
        guard model.weeklyResetCount != lastCelebrationCount else {
            return celebrationResetTask != nil
        }
        lastCelebrationCount = model.weeklyResetCount
        motionProviders = nil
        setSymbol(symbolName, color: .systemGreen)
        if !model.reduceMotion, #available(macOS 15.0, *) {
            symbolView.addSymbolEffect(.bounce, options: .repeat(3))
        }
        celebrationResetTask?.cancel()
        celebrationResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            self.celebrationResetTask = nil
            self.lastPresentation = nil
            self.update()
        }
        return true
    }

    private func configureAnimation(enabled: Bool) {
        motionRotating = enabled
    }

    /// Colors the working icon by provider: solid for one, a slow blue <-> orange
    /// cross-fade for both. Celebration green always wins. The color is baked
    /// into a non-template symbol image because the menu bar renders template
    /// images as flat monochrome and ignores contentTintColor (verified: a
    /// template symbol with contentTintColor drew gray in the menu bar).
    private func applyTint(_ presentation: StatusPresentation, celebrating: Bool) {
        let name = presentation.symbolName
        if celebrating {
            motionProviders = nil
            setSymbol(name, color: .systemGreen)
            return
        }
        let providers = presentation.activeProviders
        if providers.isEmpty {
            motionProviders = nil
            setSymbol(name, color: presentation.color)
        } else if providers.count > 1, model.reduceMotion {
            motionProviders = nil
            setSymbol(name, color: ProviderColor.bothBlend(on: barAppearance))
        } else {
            motionProviders = providers
            currentSymbolName = name
            setSymbol(name, color: ProviderColor.nsColor(for: providers[0], on: barAppearance))
        }
    }

    /// macOS re-tints each menu bar light or dark for the wallpaper behind
    /// it; the button's effectiveAppearance carries that verdict.
    private var barAppearance: ProviderColor.BarAppearance {
        let match = item.button?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        return match == .aqua ? .light : .dark
    }

    private func setSymbol(_ name: String, color: NSColor) {
        currentSymbolName = name
        currentSolidColor = color
        symbolView.image = Self.symbolImage(name, color: color, rotatedDegrees: 0)
    }

    /// Rotation is baked into the image alongside the color: rotating the view
    /// (frameCenterRotation) fights Auto Layout and blanked the icon, and layer
    /// transforms get reset by layout passes. Drawing the rotated symbol into a
    /// fresh image each frame is the one path the menu bar renders reliably.
    private static func symbolImage(
        _ name: String,
        color: NSColor,
        rotatedDegrees degrees: Double
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(paletteColors: [color])
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        base.isTemplate = false
        guard degrees != 0 else { return base }
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let transform = NSAffineTransform()
            transform.translateX(by: rect.midX, yBy: rect.midY)
            transform.rotate(byDegrees: CGFloat(degrees))
            transform.translateX(by: -rect.midX, yBy: -rect.midY)
            transform.concat()
            let baseSize = base.size
            let scale = min(rect.width / baseSize.width, rect.height / baseSize.height)
            let drawSize = NSSize(width: baseSize.width * scale, height: baseSize.height * scale)
            let origin = NSPoint(
                x: rect.midX - drawSize.width / 2,
                y: rect.midY - drawSize.height / 2
            )
            base.draw(in: NSRect(origin: origin, size: drawSize))
            return true
        }
        image.isTemplate = false
        return image
    }

    /// One frame task drives both the spin and the color sweep so neither ever
    /// restarts when the other changes. State flips (provider joins or leaves,
    /// celebration) just change what the next frame renders; the task and its
    /// clock keep running, which keeps rotation phase and sweep phase steady.
    private func reconcileMotionTask() {
        guard motionRotating || motionProviders != nil else {
            motionTask?.cancel()
            motionTask = nil
            return
        }
        guard motionTask == nil else { return }
        motionTask = Task { [weak self] in
            // Read the clock instead of accumulating the nominal step:
            // Task.sleep overshoots, and the error compounds every frame.
            let start = ContinuousClock.now
            while !Task.isCancelled {
                guard let self else { break }
                let elapsed = ContinuousClock.now - start
                let seconds = Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) * 1e-18
                self.renderMotionFrame(at: seconds)
                try? await Task.sleep(for: .seconds(Motion.frameInterval))
            }
        }
    }

    private func renderMotionFrame(at seconds: Double) {
        // The celebration bounce effect owns the icon while it plays; swapping
        // images under it would cancel the bounce.
        guard celebrationResetTask == nil, let name = currentSymbolName else { return }
        let color: NSColor
        if let providers = motionProviders, providers.count == 2 {
            let bar = barAppearance
            let claude = ProviderColor.nsColor(for: providers[0], on: bar)
            let codex = ProviderColor.nsColor(for: providers[1], on: bar)
            let phase = seconds.truncatingRemainder(dividingBy: 2 * Motion.crossfadePeriod)
            let blueShare = (1 - cos(.pi * phase / Motion.crossfadePeriod)) / 2
            // Providers are Claude-then-Codex. The cosine dwells at its
            // extremes, so an uncapped sweep parks on full orange, which reads
            // as an alert. Cap the orange end and let blue saturate fully: the
            // icon stays blue-based, and solid orange means "Claude alone".
            let orangeShare = Motion.crossfadePeakShare * (1 - blueShare)
            color = Self.blend(claude, codex, 1 - orangeShare)
        } else if let providers = motionProviders, providers.count == 1 {
            color = ProviderColor.nsColor(for: providers[0], on: barAppearance)
        } else if motionRotating, let solid = currentSolidColor {
            color = solid
        } else {
            return
        }
        let turns = motionRotating
            ? (seconds / Motion.rotationPeriod).truncatingRemainder(dividingBy: 1)
            : 0
        symbolView.image = Self.symbolImage(name, color: color, rotatedDegrees: -360 * turns)
    }

    private static func blend(_ a: NSColor, _ b: NSColor, _ fraction: Double) -> NSColor {
        let t = CGFloat(fraction)
        return NSColor(
            srgbRed: a.redComponent + (b.redComponent - a.redComponent) * t,
            green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
            blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t,
            alpha: 1
        )
    }
}

@MainActor
@Observable
final class PopoverState {
    var isPresented = false
}
