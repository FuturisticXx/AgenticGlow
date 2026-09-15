import Foundation

/// Health of a provider's hosted service as reported by its public status page.
public enum ProviderServiceStatus: Equatable, Sendable {
    case operational
    case incident(String)
}
