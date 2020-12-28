import PerfectHTTP
import Foundation

extension StartServer {
    struct AuthenticationFilter: HTTPRequestFilter {
        private let tokenMaxLifespan: Double

        public init(_ tokenMaxLifespan: Double) {
            self.tokenMaxLifespan = tokenMaxLifespan
        }

        func filter(request: HTTPRequest, response: HTTPResponse, callback: (HTTPRequestFilterResult) -> ()) {
            setupCorsHeaders(response)
            if !(request.uri.hasSuffix(SIGN_IN_ROUTE) || request.method == .options) {
                let token = request.header(.authorization) ?? ""
                if let tokenGenerationTimestamp = activeTokens[token] {
                    if NSDate().timeIntervalSince1970 - tokenGenerationTimestamp <= tokenMaxLifespan {
                        callback(.continue(request, response))
                    } else {
                        activeTokens[token] = nil
                        response.status = .forbidden
                        callback(.halt(request, response))
                    }
                } else {
                    response.status = .forbidden
                    callback(.halt(request, response))
                }
            } else {
                callback(.continue(request, response))
            }
        }
    }
}
