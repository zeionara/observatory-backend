import ArgumentParser
import PerfectHTTP
import PerfectHTTPServer
import StORM
import MongoDBStORM
import Foundation
import FoundationNetworking

func convertStringToDictionary(text: String) -> [String:AnyObject]? {
    if let data = text.data(using: .utf8) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:AnyObject]
            return json
        } catch {
            print("Something went wrong")
        }
    }
    return nil
}

extension HTTPRequest {
    public var postBody: [String: AnyObject]? {
        return convertStringToDictionary(text: postBodyString ?? "")
    }
}

enum AuthenticationError: Error {
    case cannotAuthenticate(message: String)
}

enum ExperimentError: Error {
    case executorsAreNotAvailable(message: String)
    case invalidExperimentArguments(message: String)
}

enum EncodingError: Error {
    case cannotEncodeObject(message: String)
}


func setupCorsHeaders(_ response: HTTPResponse) -> HTTPResponse {
    response.setHeader(.accessControlAllowOrigin, value: "*")
    response.setHeader(.accessControlAllowHeaders, value: "*")
    return response
}

public extension HTTPResponse {
    func appendBody<ValueType>(_ body: [String: ValueType]) where ValueType: Encodable {
        self.appendBody(string: String(data: try! JSONEncoder().encode(body), encoding: .utf8)!)
    }
}

public let USERS_COLLECTION_NAME = "test-users"
public let SIGN_IN_ROUTE = "/sign-in"
public var activeTokens = ["kk": NSDate().timeIntervalSince1970] // [String: Double]()

public let DEFAULT_LOAD_STATUS: Float = 10000

struct StartServer: ParsableCommand {

    @Option(name: .shortAndLong, help: "Port for the server to listen to")
    private var port: Int = 1720

    @Option(help: "Database host")
    private var dbHost: String = ""

    @Option(help: "Database port")
    private var dbPort: Int = 27017

    @Option(help: "Database name")
    private var dbName: String = ""

    @Option(help: "Database username")
    private var dbLogin: String = ""

    @Option(help: "Database password")
    private var dbPassword: String = ""

    @Option(help: "Token length")
    private var tokenLength: Int = 64

    @Option(help: "Set of characters which may occur in the tokens")
    var tokenCharset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    @Option(help: "Number of seconds for authentication tokens to be active")
    private var tokenMaxLifespan: Double = 604800 // 1 week

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
                // print(activeTokens)
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

    func sendOptions(request: HTTPRequest, response: HTTPResponse) {
        response.completed()
    }

    func isAuthenticated(request: HTTPRequest, response: HTTPResponse) {
        response.completed()
    }

    func signOut(request: HTTPRequest, response: HTTPResponse) {
        if let token = request.header(.authorization) {
            activeTokens[token] = nil
        }
        response.completed()
    }

    func startExperiment(request: HTTPRequest, response: HTTPResponse) {
        response.setHeader(.contentType, value: "application/json")
        do {
            let requestBody = request.postBody ?? [String: Any]()
            let selectedExecutor = try selectExecutor(requestBody)
        
            var experimentId: String? = Optional.none
            let tokenLock = NSLock()

            tokenLock.lock()

            executeExperiment(config: selectedExecutor, params: requestBody) { generatedExperimentId in
                experimentId = generatedExperimentId
                tokenLock.unlock()
            }

            tokenLock.lock()
            if let unwrappedExperimentId = experimentId {
                response.appendBody(["experiment-id": unwrappedExperimentId])
            } else {
                throw ExperimentError.invalidExperimentArguments(message: "Provided parameter values are not correct")
            }
        } catch {
            response.status = .internalServerError
            response.appendBody(["error": error.localizedDescription])
        }
        response.completed()
    }

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

    mutating func run() throws {
        print("Starting an http server...")
        print("Connecting to the databased on \(dbHost)...")

        MongoDBConnection.host = dbHost
        MongoDBConnection.database = dbName
        MongoDBConnection.port = dbPort

        MongoDBConnection.authmode = .standard
        MongoDBConnection.username = dbLogin
        MongoDBConnection.password = dbPassword
        
        var routes = Routes()
        routes.add(method: .post, uri: SIGN_IN_ROUTE, handler: signIn)
        routes.add(method: .post, uri: "/sign-out", handler: signOut)
        routes.add(method: .post, uri: "/start-experiment", handler: startExperiment)
        routes.add(method: .get, uri: "/is-authenticated", handler: isAuthenticated)
        routes.add(method: .options, uri: "/*", handler: sendOptions)
        
        try HTTPServer.launch(
            name: "localhost",
            port: port,
            routes: routes,
            requestFilters: [
                (
                    AuthenticationFilter(tokenMaxLifespan),
                    HTTPFilterPriority.high
                )
            ],
            responseFilters: [
                (
                    PerfectHTTPServer.HTTPFilter.contentCompression(data: [:]),
                    HTTPFilterPriority.high
                )
            ]
        )
    }
}

struct ObservatoryBackend: ParsableCommand {
    static var configuration = CommandConfiguration(
            abstract: "Backend components for managing experiments on the machine learning models",
            subcommands: [StartServer.self],
            defaultSubcommand: StartServer.self
    )
}

ObservatoryBackend.main()
