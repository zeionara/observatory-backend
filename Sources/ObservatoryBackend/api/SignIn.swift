import PerfectHTTP
import Foundation

extension StartServer {
    func generateToken() -> String {
        return String((0..<tokenLength).map{ _ in tokenCharset.randomElement()! })
    }

    func signIn(request: HTTPRequest, response: HTTPResponse) {
        do {
            let requestBody = request.postBody ?? [String: Any]()
            let user = User()
            try user.find(["login": requestBody["login"] ?? ""])
            
            if user.password == requestBody["password"] as? String {
                let token = generateToken()
                activeTokens[token] = NSDate().timeIntervalSince1970
                response.setHeader(.contentType, value: "application/json")
                response.appendBody(string: String(data: try! JSONEncoder().encode(["token": token]), encoding: .utf8)!)
            } else {
                throw AuthenticationError.cannotAuthenticate(message: "Password is not valid for user \(user.login)")
            }
        } catch {
            response.setHeader(.contentType, value: "text/html")
            response.status = .forbidden
            response.appendBody(string: "<html><title>Exception!</title><body>Authentication was not successful</body></html>")
        }
        response.completed()
    }
}