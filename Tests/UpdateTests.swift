import Foundation

enum UpdateTests {
    @MainActor
    static func run() async throws {
        func metadata(_ tag: String, url: String? = nil, draft: Bool = false, prerelease: Bool = false) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["tag_name": tag,
                "html_url": url ?? "https://github.com/breadoncee/Auspex/releases/tag/\(tag)",
                "draft": draft, "prerelease": prerelease])
        }
        func rejected(_ data: Data) -> Bool {
            do { _ = try UpdateChecker.result(data: data, installedVersion: "1.3.0"); return false }
            catch { return true }
        }
        let newer = try UpdateChecker.result(data: metadata("v1.10.0"), installedVersion: "1.3.0")
        guard case .available = newer else { fatalError("Versions must compare numerically") }
        let same = try UpdateChecker.result(data: metadata("v1.3.0"), installedVersion: "1.3.0")
        let older = try UpdateChecker.result(data: metadata("v1.2.0"), installedVersion: "1.3.0")
        precondition(same == .current && older == .current, "Never recommend a downgrade")
        for data in [try metadata("v1.4.0", draft: true),
                     try metadata("v1.4.0", prerelease: true),
                     try metadata("v1.4.0", url: "https://example.com/download"),
                     try metadata("v1.4.0", url: "https://github.com/other/app/releases/tag/v1.4.0"),
                     try metadata("v1.4.0", url: "http://github.com/breadoncee/Auspex/releases/tag/v1.4.0")] {
            precondition(rejected(data), "Invalid or untrusted release metadata must be rejected")
        }
        precondition(rejected(Data("broken".utf8)))
        precondition(ReleaseVersion("1.3.0-beta") == nil && ReleaseVersion("1..3") == nil)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdateSuccessProtocol.self]
        let checker = UpdateChecker(installedVersion: "1.3.0", session: URLSession(configuration: configuration))
        await checker.check()
        guard case .available("v1.4.0", _) = checker.state else { fatalError("Valid response should offer an update") }
        configuration.protocolClasses = [UpdateFailureProtocol.self]
        let offline = UpdateChecker(installedVersion: "1.3.0", session: URLSession(configuration: configuration))
        await offline.check()
        guard case .failed = offline.state else { fatalError("Network errors should allow a retry") }
        print("PASS: release versions, downgrade prevention and update metadata validation")
    }
}

private final class UpdateSuccessProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"tag_name":"v1.4.0","html_url":"https://github.com/breadoncee/Auspex/releases/tag/v1.4.0","draft":false,"prerelease":false}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class UpdateFailureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
