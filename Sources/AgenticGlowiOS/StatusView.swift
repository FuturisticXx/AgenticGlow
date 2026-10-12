import CloudKit
import SwiftUI
import AgenticGlowCore

/// One screen: which Mac the phone is showing, how current that is, and
/// what to do if it is not. Plain system lists, because the product here
/// is the widget on the Home Screen, not this app.
struct StatusView: View {
    let model: SyncModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    switch model.state {
                    case let .loaded(envelope):
                        loadedRows(envelope)
                    case .noSnapshotYet:
                        Label("Waiting for your Mac", systemImage: "hourglass")
                        Text("Turn on \"Sync to the iPhone widget\" in AgenticGlow's Settings on your Mac. Both devices need the same iCloud account.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    case .corrupted:
                        Label("Unavailable", systemImage: "exclamationmark.triangle")
                        Text("The synchronized state could not be read. It will be replaced the next time your Mac publishes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    case .notConfigured:
                        Label("Set up AgenticGlow", systemImage: "gearshape")
                        Text("The shared container is unavailable on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Mac")
                }

                Section("iCloud") {
                    LabeledContent("Account", value: accountLabel)
                    if let lastRefreshAt = model.lastRefreshAt {
                        LabeledContent("Last checked", value: lastRefreshAt.formatted(date: .omitted, time: .shortened))
                    }
                    if let lastError = model.lastError {
                        Text(lastError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        if model.isRefreshing {
                            ProgressView()
                        } else {
                            Text("Check Now")
                        }
                    }
                    .disabled(model.isRefreshing)
                }

                #if DEBUG
                diagnosticsSection
                #endif

                Section {
                    Text("Your Mac observes Codex, Claude, and Cursor and publishes only what its own widget shows: project names, session phases, allowance percentages, and reset times. No credentials or prompts leave the Mac. Add the AgenticGlow widget to your Home Screen to see it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("AgenticGlow")
            .refreshable { await model.refresh() }
        }
    }

    #if DEBUG
    /// Debug builds only: enough to prove the receiving path on a real
    /// phone without any external tooling. Names, times, hashes, and
    /// verdicts; never payload contents.
    private var diagnosticsSection: some View {
        Section("Diagnostics (debug build)") {
            let now = Date()
            LabeledContent("iCloud account", value: accountLabel)
            switch model.state {
            case let .loaded(envelope):
                LabeledContent("Source Mac", value: envelope.sourceMacName)
                LabeledContent("Mac ID", value: String(envelope.sourceMacID.prefix(8)) + "…")
                LabeledContent("Mac observedAt", value: envelope.observedAt.formatted(date: .abbreviated, time: .standard))
                LabeledContent("Snapshot schema", value: "\(envelope.snapshot.schemaVersion)")
                LabeledContent("Snapshot hash", value: SyncedStateFingerprint.hash(of: envelope))
                LabeledContent("Freshness", value: SyncFreshness.evaluate(observedAt: envelope.observedAt, now: now).summary)
                LabeledContent("App Group cache", value: "loaded")
            case .noSnapshotYet:
                LabeledContent("App Group cache", value: "empty")
            case .corrupted:
                LabeledContent("App Group cache", value: "corrupted")
            case .notConfigured:
                LabeledContent("App Group cache", value: "not configured")
            }
            LabeledContent("Cache written", value: model.cacheWrittenAt?.formatted(date: .abbreviated, time: .standard) ?? "never")
            LabeledContent("Last CloudKit fetch", value: model.lastFetchAt?.formatted(date: .abbreviated, time: .standard) ?? "never")
            LabeledContent("CloudKit fetch status", value: model.lastFetchStatus)
            Button("Refresh & Verify") {
                Task { await model.refreshAndVerify() }
            }
            if let report = model.verificationReport {
                Text(report.text)
                    .font(.footnote.monospaced())
                    .foregroundStyle(report.passed ? Color.primary : Color.red)
                    .textSelection(.enabled)
            }
        }
    }
    #endif

    @ViewBuilder
    private func loadedRows(_ envelope: SyncedStateEnvelope) -> some View {
        let now = Date()
        let freshness = SyncFreshness.evaluate(observedAt: envelope.observedAt, now: now)
        LabeledContent("Name", value: envelope.sourceMacName)
        LabeledContent("Observed", value: WidgetSnapshotFormatting.lastUpdatedLabel(envelope.observedAt, now: now))
        LabeledContent("Status", value: statusLabel(freshness))
        LabeledContent("Sessions", value: "\(envelope.snapshot.sessions.count)")
        LabeledContent("Allowances", value: "\(envelope.snapshot.allowances.count)")
    }

    private func statusLabel(_ freshness: SyncFreshness) -> String {
        switch freshness {
        case .fresh: "Current"
        case .stale: "Stale"
        case .offline: "Mac unavailable"
        }
    }

    private var accountLabel: String {
        switch model.accountStatus {
        case .available: "Signed in"
        case .noAccount: "Not signed in"
        case .restricted: "Restricted"
        case .couldNotDetermine: "Unknown"
        case .temporarilyUnavailable: "Temporarily unavailable"
        case .none: "Not checked yet"
        @unknown default: "Unknown"
        }
    }
}
