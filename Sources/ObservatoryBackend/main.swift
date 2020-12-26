import ArgumentParser
import PerfectHTTP
import PerfectHTTPServer
import StORM
import MongoDBStORM
import Foundation

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

func setupCorsHeaders(_ response: HTTPResponse) -> HTTPResponse {
    response.setHeader(.accessControlAllowOrigin, value: "*")
    response.setHeader(.accessControlAllowHeaders, value: "*")
    return response
}

// extension Encodable {
//   func asDictionary() throws -> [String: Any] {
//     let data = try JSONEncoder().encode(self)
//     guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
//       throw EncodingError.cannotEncode(message: "Cannot encode the given object") 
//     }
//     return dictionary
//   }
// }

// public extension Array where Element == (String, String) {
//     subscript(index: String) -> String? {
//         for item in self {
//             if item.0 == index {
//                 return item.1
//             }
//         }
//         return Optional.none
//     } 
// }

// private func encodeCredentials(login: String?, password: String?) -> String? {
//     if let login_ = login, let password_ = password {
//         return "\(login_):\(password_)".data(using: .utf8)!.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
//     }
//     return Optional.none
// }

public let USERS_COLLECTION_NAME = "test-users"
public let SIGN_IN_ROUTE = "/sign-in"
public var activeTokens = [String: Double]()

// public let EXPERIMENTS_COLLECTION_NAME = "test-experiments"
// public let N_MAX_CONCURRENT_EXPERIMENTS = 2

// private var experimentConcurrencySemaphore = DispatchSemaphore(value: N_MAX_CONCURRENT_EXPERIMENTS)
// private var nActiveExperimentsLock = NSLock()
// private var nActiveExperiments = 0

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

    // func parseRequestParameter(request: HTTPRequest, paramName: String, flag: String) -> [String] {
    //     if let paramValue = request.param(name: paramName) {
    //         return [flag, paramValue]
    //     } else {
    //         return []
    //     }
    // }

    // func runExperiment(request: HTTPRequest, response: HTTPResponse) {
    //     do {

    //         // Initialize a new experiment

    //         let experiment = Experiment()
            
    //         experiment.id = experiment.newUUID()
    //         experiment.isCompleted = false
    //         experiment.startTimestamp = NSDate().timeIntervalSince1970
    //         experiment.progress = 0.0

    //         let params = parseRequestParameter(request: request, paramName: "model", flag: "-m") + parseRequestParameter(request: request, paramName: "dataset", flag: "-d")
            
    //         var command = try CrossValidate.parse(params)
    //         experiment.params = try command.asDictionary()
    //         try experiment.save()

    //         DispatchQueue.global(qos: .userInitiated).async { [self] in

    //             // Increment number of active experiments
                
    //             nActiveExperimentsLock.lock()
    //             // let runningExperimentIndex = nActiveExperiments
    //             nActiveExperiments += 1
    //             nActiveExperimentsLock.unlock()

    //             // Obtain a semaphore

    //             experimentConcurrencySemaphore.wait()
                
    //             // for i in 0..<10 {
    //             //     print("\(runningExperimentIndex): \(i)")
    //             //     sleep(2)
    //             // }

    //             // Run the initialized experiment

    //             let metrics = try! command.run()

    //             if experiment.progress < 1 {
    //                 experiment.progress = 1
    //             }
    //             experiment.completionTimestamp = NSDate().timeIntervalSince1970
    //             experiment.isCompleted = true
    //             experiment.metrics = metrics
    //             experiment.params = try! command.asDictionary()

    //             try! experiment.save()

    //             // Release a semaphore

    //             experimentConcurrencySemaphore.signal()

    //             // Decrement number of running experiments
                
    //             nActiveExperimentsLock.lock()
    //             nActiveExperiments -= 1
    //             nActiveExperimentsLock.unlock()

    //         }
    //         response.setHeader(.contentType, value: "application/json")
    //         // response.appendBody(string: try experiment.asDataDict(1).jsonEncodedString())
    //         response.appendBody(string: String(data: try! JSONEncoder().encode(["experiment-id": experiment.id]), encoding: .utf8)!)
    //     } catch {
    //         response.setHeader(.contentType, value: "text/html")
    //         response.appendBody(string: "<html><title>Exception!</title><body>\(error)</body></html>")
    //     }
    //     response.completed()
    // }

    func generateToken() -> String {
        return String((0..<tokenLength).map{ _ in tokenCharset.randomElement()! })
    }

    func signIn(request: HTTPRequest, response: HTTPResponse) {
        do {
            let requestBody = request.postBody!
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
                        // print(NSDate().timeIntervalSince1970 - tokenGenerationTimestamp)
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
        routes.add(method: .post, uri: "sign-out", handler: signOut)
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
