import Foundation

public struct ExecutorConfiguration {
    private let baseUrlString: String
    private let login: String
    private let password: String

    public init(url: String, login: String, password: String) {
        baseUrlString = url
        self.login = login
        self.password = password
    }

    public var loadStatusUrl: URL {
        return URL(string: "\(baseUrlString)/load-status")!
    }

    public var baseUrl: URL {
        return URL(string: baseUrlString)!
    }

    public var credentials: String {
        return "Basic " + "\(login):\(password)".data(using: .utf8)!.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
    }
}