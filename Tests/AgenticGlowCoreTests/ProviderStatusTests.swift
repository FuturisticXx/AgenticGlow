import Foundation
import XCTest
@testable import AgenticGlowCore

final class StatusPageNormalizerTests: XCTestCase {
    func testIndicatorNoneIsOperational() throws {
        let status = try StatusPageNormalizer.normalize(json(
            indicator: "none",
            description: "All Systems Operational"
        ))

        XCTAssertEqual(status, .operational)
    }

    func testMinorIndicatorIsOperational() throws {
        let status = try StatusPageNormalizer.normalize(json(
            indicator: "minor",
            description: "Partial System Degradation"
        ))

        XCTAssertEqual(status, .operational)
    }

    func testMaintenanceIndicatorIsOperational() throws {
        let status = try StatusPageNormalizer.normalize(json(
            indicator: "maintenance",
            description: "Scheduled Maintenance"
        ))

        XCTAssertEqual(status, .operational)
    }

    func testMajorIndicatorIsIncidentWithDescription() throws {
        let status = try StatusPageNormalizer.normalize(json(
            indicator: "major",
            description: "Major Service Outage"
        ))

        XCTAssertEqual(status, .incident("Major Service Outage"))
    }

    func testCriticalIndicatorWithoutDescriptionUsesFallback() throws {
        let status = try StatusPageNormalizer.normalize(json(
            indicator: "critical",
            description: nil
        ))

        XCTAssertEqual(status, .incident("Service incident"))
    }

    func testGarbagePayloadThrows() {
        XCTAssertThrowsError(
            try StatusPageNormalizer.normalize(Data("not json".utf8))
        )
    }

    private func json(indicator: String, description: String?) -> Data {
        var status: [String: Any] = ["indicator": indicator]
        if let description {
            status["description"] = description
        }
        return try! JSONSerialization.data(withJSONObject: ["status": status])
    }
}

final class ProviderStatusMonitorTests: XCTestCase {
    func testDisabledMonitorNeverFetchesAndReportsNil() async {
        let requester = CountingStatusRequester(result: .success(incidentData()))
        let monitor = ProviderStatusMonitor(requester: requester, ttl: 600, now: { .distantPast })

        await monitor.refreshIfStale()

        let status = await monitor.status(for: .claude)
        XCTAssertNil(status)
        let count = await requester.fetchCount
        XCTAssertEqual(count, 0)
    }

    func testEnabledMonitorFetchesAndReportsIncident() async {
        let requester = CountingStatusRequester(result: .success(incidentData()))
        let monitor = ProviderStatusMonitor(
            requester: requester,
            ttl: 600,
            now: { Date(timeIntervalSince1970: 1_783_099_000) }
        )

        await monitor.setEnabled(true)
        await monitor.refreshIfStale()

        let status = await monitor.status(for: .claude)
        XCTAssertEqual(status, .incident("Partial System Degradation"))
    }

    func testFreshStatusIsNotRefetchedWithinTTL() async {
        let requester = CountingStatusRequester(result: .success(incidentData()))
        let clock = ClockBox(Date(timeIntervalSince1970: 1_783_099_000))
        let monitor = ProviderStatusMonitor(requester: requester, ttl: 600, now: { clock.now })

        await monitor.setEnabled(true)
        await monitor.refreshIfStale()
        clock.advance(60)
        await monitor.refreshIfStale()

        let count = await requester.fetchCount
        XCTAssertEqual(count, AgentProvider.allCases.count)

        clock.advance(700)
        await monitor.refreshIfStale()
        let refreshedCount = await requester.fetchCount
        XCTAssertEqual(refreshedCount, AgentProvider.allCases.count * 2)
    }

    func testFetchFailureReportsNilThenRecovers() async {
        let requester = CountingStatusRequester(result: .failure(URLError(.timedOut)))
        let clock = ClockBox(Date(timeIntervalSince1970: 1_783_099_000))
        let monitor = ProviderStatusMonitor(requester: requester, ttl: 600, now: { clock.now })

        await monitor.setEnabled(true)
        await monitor.refreshIfStale()
        let status = await monitor.status(for: .claude)
        XCTAssertNil(status)

        await requester.setResult(.success(incidentData()))
        clock.advance(700)
        await monitor.refreshIfStale()
        let recovered = await monitor.status(for: .claude)
        XCTAssertEqual(recovered, .incident("Partial System Degradation"))
    }

    func testDisablingClearsState() async {
        let requester = CountingStatusRequester(result: .success(incidentData()))
        let monitor = ProviderStatusMonitor(
            requester: requester,
            ttl: 600,
            now: { Date(timeIntervalSince1970: 1_783_099_000) }
        )

        await monitor.setEnabled(true)
        await monitor.refreshIfStale()
        await monitor.setEnabled(false)

        let status = await monitor.status(for: .claude)
        XCTAssertNil(status)
    }

    private func incidentData() -> Data {
        Data(#"{"status":{"indicator":"major","description":"Partial System Degradation"}}"#.utf8)
    }
}

private final class ClockBox: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(_ date: Date) {
        self.date = date
    }

    var now: Date {
        lock.withLock { date }
    }

    func advance(_ interval: TimeInterval) {
        lock.withLock { date = date.addingTimeInterval(interval) }
    }
}

private actor CountingStatusRequester: ProviderStatusRequesting {
    private(set) var fetchCount = 0
    private var result: Result<Data, Error>

    init(result: Result<Data, Error>) {
        self.result = result
    }

    func setResult(_ result: Result<Data, Error>) {
        self.result = result
    }

    func fetchStatus(for provider: AgentProvider) async throws -> Data {
        fetchCount += 1
        return try result.get()
    }
}
