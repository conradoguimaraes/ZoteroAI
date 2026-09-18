#if os(macOS)
import Foundation
import Security

final class TokenStore {
    static let shared = TokenStore()

    private let fileManager = FileManager.default
    private(set) var token: String = ""
    let directoryURL: URL
    let tokenURL: URL

    private init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directoryURL = base.appendingPathComponent("Zotero Metadata Enricher", isDirectory: true)
        tokenURL = directoryURL.appendingPathComponent("token", isDirectory: false)
    }

    func prepare() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        if let existing = try? String(contentsOf: tokenURL, encoding: .utf8).zmeTrimmed,
           existing.count >= 32 {
            token = existing
            return
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw NSError(domain: "ZME.TokenStore", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not generate a secure helper token."])
        }

        token = bytes.map { String(format: "%02x", $0) }.joined()
        try token.write(to: tokenURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenURL.path)
    }
}
#endif
