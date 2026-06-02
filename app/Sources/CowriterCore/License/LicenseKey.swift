import Foundation

/// The signed payload that constitutes a license. Issued server-side (Stripe
/// webhook) and verified offline by the app, so day-to-day use never phones home.
public struct LicenseKey: Equatable, Codable, Sendable {
    /// Buyer email the key was issued to.
    public let email: String
    /// Stripe checkout/order identifier, for support + reactivation.
    public let orderID: String
    /// When the license was issued.
    public let issuedAt: Date
    /// Product/edition, e.g. "cowriter-mac".
    public let product: String

    public init(email: String, orderID: String, issuedAt: Date, product: String) {
        self.email = email
        self.orderID = orderID
        self.issuedAt = issuedAt
        self.product = product
    }

    /// The exact bytes that are signed. Stable, sorted-key JSON so the issuer and
    /// verifier agree byte-for-byte.
    public func canonicalData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

/// A license key plus its detached signature, as delivered to the user
/// (base64url, joined by a separator). This is what the user pastes into the app.
public struct SignedLicense: Equatable, Sendable {
    public let key: LicenseKey
    public let signature: Data

    public init(key: LicenseKey, signature: Data) {
        self.key = key
        self.signature = signature
    }
}
