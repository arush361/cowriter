import Foundation
import CryptoKit

/// Verifies signed licenses offline using an Ed25519 public key embedded in the
/// app. The matching private key lives only on the issuing server (the Stripe
/// webhook handler). Because verification is local, the app keeps working with no
/// network access after a one-time activation.
public struct LicenseManager: Sendable {
    public enum Status: Equatable, Sendable {
        case unlicensed
        case licensed(LicenseKey)
        case invalid(reason: String)
    }

    private let publicKey: Curve25519.Signing.PublicKey

    /// - Parameter publicKeyRaw: the 32-byte Ed25519 public key shipped in the app.
    public init(publicKeyRaw: Data) throws {
        self.publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyRaw)
    }

    /// Verify a signed license against the embedded public key.
    public func verify(_ license: SignedLicense) -> Status {
        do {
            let data = try license.key.canonicalData()
            if publicKey.isValidSignature(license.signature, for: data) {
                return .licensed(license.key)
            } else {
                return .invalid(reason: "Signature does not match.")
            }
        } catch {
            return .invalid(reason: "Malformed license payload.")
        }
    }

    // MARK: - Encoding helpers for the pasteable key string

    /// Wire format the user pastes: base64url(canonicalJSON) + "." + base64url(signature).
    public static func encode(_ license: SignedLicense) throws -> String {
        let payload = try license.key.canonicalData()
        return base64url(payload) + "." + base64url(license.signature)
    }

    /// Parse the pasteable string back into a `SignedLicense`.
    public static func decode(_ string: String) throws -> SignedLicense {
        let parts = string.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let payload = base64urlDecode(parts[0]),
              let signature = base64urlDecode(parts[1]) else {
            throw LicenseError.malformed
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let key = try decoder.decode(LicenseKey.self, from: payload)
        return SignedLicense(key: key, signature: signature)
    }

    public enum LicenseError: Error, Equatable, Sendable {
        case malformed
    }

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64urlDecode(_ string: String) -> Data? {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        return Data(base64Encoded: s)
    }
}
