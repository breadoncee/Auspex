import Foundation
import Observation

/// Checks only public release metadata, on demand. Installation stays with the user.
@MainActor
@Observable
final class UpdateChecker {
    enum State: Equatable {
        case idle, checking, current, available(String, URL), failed(String)
    }

    private(set) var state: State = .idle
    private let installedVersion: String
    private let session: URLSession

    init(installedVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
         session: URLSession? = nil) {
        self.installedVersion = installedVersion
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        self.session = session ?? URLSession(configuration: configuration)
    }

    func check() async {
        guard state != .checking else { return }
        state = .checking
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/breadoncee/Auspex/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Auspex-update-check", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw CheckError.invalidResponse }
            guard response.statusCode == 200 else {
                state = .failed(response.statusCode == 403 || response.statusCode == 429
                    ? "GitHub is busy. Please try again later."
                    : "Couldn’t check releases. Please try again later.")
                return
            }
            state = try Self.result(data: data, installedVersion: installedVersion)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed("Couldn’t check for updates. Check your connection and try again.")
        }
    }

    static func result(data: Data, installedVersion: String) throws -> State {
        guard data.count < 1_048_576 else { throw CheckError.invalidResponse }
        let release = try JSONDecoder().decode(Release.self, from: data)
        guard !release.draft, !release.prerelease,
              let latest = ReleaseVersion(release.tag_name), let installed = ReleaseVersion(installedVersion),
              let url = URL(string: release.html_url), url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil, url.port == nil,
              url.path == "/breadoncee/Auspex/releases/tag/\(release.tag_name)",
              url.query == nil, url.fragment == nil else { throw CheckError.invalidResponse }
        return latest > installed ? .available(release.tag_name, url) : .current
    }

    private struct Release: Decodable {
        var tag_name: String
        var html_url: String
        var draft: Bool
        var prerelease: Bool
    }
    private enum CheckError: Error { case invalidResponse }
}

struct ReleaseVersion: Comparable {
    let major: UInt
    let minor: UInt
    let patch: UInt

    init?(_ string: String) {
        let value = string.hasPrefix("v") ? String(string.dropFirst()) : string
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let major = UInt(parts[0]), let minor = UInt(parts[1]), let patch = UInt(parts[2]) else { return nil }
        self.major = major; self.minor = minor; self.patch = patch
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
