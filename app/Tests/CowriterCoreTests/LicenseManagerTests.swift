import XCTest
import CryptoKit
@testable import CowriterCore

final class LicenseManagerTests: XCTestCase {
    // Generate an ephemeral key pair to simulate the issuing server, then verify
    // the app-side offline verification accepts a properly signed license and
    // rejects tampering.
    private func makeSignedLicense(
        privateKey: Curve25519.Signing.PrivateKey,
        email: String = "buyer@example.com"
    ) throws -> SignedLicense {
        let key = LicenseKey(
            email: email,
            orderID: "cs_test_123",
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            product: "cowriter-mac"
        )
        let signature = try privateKey.signature(for: key.canonicalData())
        return SignedLicense(key: key, signature: signature)
    }

    func testValidLicenseIsAccepted() throws {
        let priv = Curve25519.Signing.PrivateKey()
        let manager = try LicenseManager(publicKeyRaw: priv.publicKey.rawRepresentation)
        let license = try makeSignedLicense(privateKey: priv)

        if case .licensed(let key) = manager.verify(license) {
            XCTAssertEqual(key.email, "buyer@example.com")
        } else {
            XCTFail("Expected licensed status")
        }
    }

    func testWrongPublicKeyIsRejected() throws {
        let issuer = Curve25519.Signing.PrivateKey()
        let attacker = Curve25519.Signing.PrivateKey()
        // App ships the attacker's public key, license signed by the real issuer.
        let manager = try LicenseManager(publicKeyRaw: attacker.publicKey.rawRepresentation)
        let license = try makeSignedLicense(privateKey: issuer)

        if case .invalid = manager.verify(license) {
            // expected
        } else {
            XCTFail("Expected invalid status for mismatched key")
        }
    }

    func testTamperedPayloadIsRejected() throws {
        let priv = Curve25519.Signing.PrivateKey()
        let manager = try LicenseManager(publicKeyRaw: priv.publicKey.rawRepresentation)
        let original = try makeSignedLicense(privateKey: priv)

        // Swap the email but keep the original signature.
        let tampered = SignedLicense(
            key: LicenseKey(
                email: "attacker@example.com",
                orderID: original.key.orderID,
                issuedAt: original.key.issuedAt,
                product: original.key.product
            ),
            signature: original.signature
        )

        if case .invalid = manager.verify(tampered) {
            // expected
        } else {
            XCTFail("Expected invalid status for tampered payload")
        }
    }

    func testEncodeDecodeRoundTrip() throws {
        let priv = Curve25519.Signing.PrivateKey()
        let license = try makeSignedLicense(privateKey: priv)

        let encoded = try LicenseManager.encode(license)
        let decoded = try LicenseManager.decode(encoded)

        XCTAssertEqual(decoded.key, license.key)
        XCTAssertEqual(decoded.signature, license.signature)

        // And the decoded license still verifies.
        let manager = try LicenseManager(publicKeyRaw: priv.publicKey.rawRepresentation)
        if case .licensed = manager.verify(decoded) {
            // expected
        } else {
            XCTFail("Round-tripped license should verify")
        }
    }

    func testMalformedKeyStringThrows() {
        XCTAssertThrowsError(try LicenseManager.decode("not-a-valid-key"))
    }
}
