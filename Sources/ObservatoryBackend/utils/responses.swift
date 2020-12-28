import PerfectHTTP
import Foundation

func setupCorsHeaders(_ response: HTTPResponse) {
    response.setHeader(.accessControlAllowOrigin, value: "*")
    response.setHeader(.accessControlAllowHeaders, value: "*")
}

public extension HTTPResponse {
    func appendBody<ValueType>(_ body: [String: ValueType]) where ValueType: Encodable {
        self.appendBody(string: String(data: try! JSONEncoder().encode(body), encoding: .utf8)!)
    }
}
