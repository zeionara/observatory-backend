import PerfectHTTP

extension StartServer {
    func signOut(request: HTTPRequest, response: HTTPResponse) {
        if let token = request.header(.authorization) {
            activeTokens[token] = nil
        }
        response.completed()
    }
}