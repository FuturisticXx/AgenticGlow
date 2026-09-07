import Foundation

public protocol CursorUsageRequesting: Sendable {
    func fetchUsage(sessionCookie: String) async throws -> Data
}

/// Cursor allowance from the account's own cursor.com dashboard session.
///
/// Cursor publishes no individual usage API (its Admin and Analytics APIs
/// are Enterprise-team only), so this reads the same private endpoint the
/// dashboard itself calls, using a session cookie the user pastes into
/// Usage Access. AgenticGlow never reads Cursor's application storage or
/// any browser cookie store. See docs/provider-allowance-feasibility.md.
public struct CursorAllowanceAdapter: AllowanceProviding {
    public let provider = AgentProvider.cursor
    private let sessionCookie: @Sendable () throws -> String
    private let requester: any CursorUsageRequesting
    private let now: @Sendable () -> Date

    public init(
        sessionCookie: @escaping @Sendable () throws -> String,
        requester: any CursorUsageRequesting = CursorWebUsageClient(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.sessionCookie = sessionCookie
        self.requester = requester
        self.now = now
    }

    public func fetch() async throws -> ProviderAllowance {
        let cookie = try sessionCookie()
        guard !cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AllowanceAdapterError.unavailable(
                "Add a Cursor session cookie in Usage Access."
            )
        }
        let data = try await requester.fetchUsage(sessionCookie: cookie)
        do {
            return try CursorAllowanceNormalizer.normalize(data, fetchedAt: now())
        } catch let error as AllowanceAdapterError {
            throw error
        } catch {
            throw AllowanceAdapterError.invalidResponse
        }
    }
}

public struct CursorWebUsageClient: CursorUsageRequesting {
    /// Read-only. A GET that returns the account's usage summary and
    /// changes nothing on the account.
    public static let usageURL = "https://cursor.com/api/usage-summary"

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchUsage(sessionCookie: String) async throws -> Data {
        let request = try Self.makeRequest(sessionCookie: sessionCookie)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AllowanceAdapterError.unavailable("Cursor usage is temporarily unavailable.")
        }
        try Self.validate(statusCode: http.statusCode)
        return data
    }

    public static func makeRequest(sessionCookie: String) throws -> URLRequest {
        guard let url = URL(string: usageURL) else {
            throw AllowanceAdapterError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.timeoutInterval = 15
        return request
    }

    public static func validate(statusCode: Int) throws {
        switch statusCode {
        case 200 ..< 300:
            return
        case 401, 403:
            // Kept distinct from every other failure so an expired cookie
            // reads as "reconnect", never as "no allowance left".
            throw AllowanceAdapterError.unavailable(
                "Cursor session cookie expired. Update Usage Access."
            )
        case 429:
            throw AllowanceAdapterError.rateLimited(retryAfter: nil)
        default:
            throw AllowanceAdapterError.unavailable("Cursor usage is temporarily unavailable.")
        }
    }
}

/// Turns the dashboard's usage summary into the two pools Cursor's plans
/// actually meter, and nothing else.
///
/// `individualUsage.plan` reports two independent lane percentages that
/// each run 0-100 against their own denominator:
///
/// - `autoPercentUsed`: Cursor's own models (Composer, Auto, Cursor Grok).
/// - `apiPercentUsed`: third-party named models.
///
/// They are not two views of one number and are never combined here.
/// `totalPercentUsed` is deliberately ignored: a single Cursor figure
/// would have to blend two different denominators to exist.
public enum CursorAllowanceNormalizer {
    public static let cursorModelsPoolID = "cursorModels"
    public static let otherModelsPoolID = "otherModels"

    public static func normalize(_ data: Data, fetchedAt: Date) throws -> ProviderAllowance {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let plan = response.individualUsage?.plan
        // Both lanes are metered against the subscription's billing
        // cycle, so they share one reset.
        let reset = parseDate(response.billingCycleEnd)
        // An unlimited plan meters nothing, so any percentage would be a
        // fiction. Say so through the existing unavailable state instead
        // of drawing a bar with no denominator behind it.
        if response.isUnlimited == true {
            throw AllowanceAdapterError.unavailable(
                "Cursor reports unlimited usage on this plan, so there is no allowance to show."
            )
        }

        let pools = [
            AllowancePool(
                id: cursorModelsPoolID,
                label: "Cursor Models",
                percentUsed: percent(plan?.autoPercentUsed),
                resetAt: reset
            ),
            AllowancePool(
                id: otherModelsPoolID,
                label: "Other Models",
                percentUsed: percent(plan?.apiPercentUsed),
                resetAt: reset
            )
        ]

        // A response carrying neither lane is not a zeroed account; it is
        // a plan whose shape this integration cannot read (a legacy
        // request-based plan, or a team seat with no individual block).
        guard pools.contains(where: { $0.percentUsed != nil }) else {
            throw AllowanceAdapterError.unavailable(
                "Cursor did not report usage pools for this plan."
            )
        }

        return ProviderAllowance(
            provider: .cursor,
            currentWindowLabel: "Billing cycle",
            currentPercentUsed: nil,
            currentResetAt: nil,
            weeklyPercentUsed: nil,
            weeklyResetAt: nil,
            pools: pools,
            fetchedAt: fetchedAt
        )
    }

    /// Cursor reports these already in percentage units, including
    /// fractional values below 1.0 (0.36 means 0.36%, not 36%). A
    /// non-finite or negative value is dropped rather than clamped, so a
    /// malformed field never renders as a real reading.
    private static func percent(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let milliseconds = Double(value), milliseconds > 0 {
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    /// Only the fields AgenticGlow displays are decoded. Unknown keys are
    /// ignored, so Cursor adding fields cannot break the parse. Nothing
    /// identifying (email, account ID, spend) is read or retained.
    private struct Response: Decodable {
        let billingCycleEnd: String?
        let isUnlimited: Bool?
        let individualUsage: IndividualUsage?

        /// `billingCycleEnd` has been seen as both an ISO 8601 string and
        /// an epoch-milliseconds number. Accepting either keeps a reset
        /// date from taking the whole response down with it.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let text = try? container.decodeIfPresent(String.self, forKey: .billingCycleEnd) {
                billingCycleEnd = text
            } else if let number = try? container.decodeIfPresent(Double.self, forKey: .billingCycleEnd) {
                billingCycleEnd = String(number)
            } else {
                billingCycleEnd = nil
            }
            isUnlimited = try? container.decodeIfPresent(Bool.self, forKey: .isUnlimited)
            individualUsage = try? container.decodeIfPresent(IndividualUsage.self, forKey: .individualUsage)
        }

        enum CodingKeys: String, CodingKey {
            case billingCycleEnd
            case isUnlimited
            case individualUsage
        }
    }

    private struct IndividualUsage: Decodable {
        let plan: Plan?
    }

    private struct Plan: Decodable {
        let autoPercentUsed: Double?
        let apiPercentUsed: Double?
    }
}
