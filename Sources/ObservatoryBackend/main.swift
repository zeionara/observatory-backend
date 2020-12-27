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
}

enum EncodingError: Error {
    case cannotEncodeObject(message: String)
}


func setupCorsHeaders(_ response: HTTPResponse) -> HTTPResponse {
    response.setHeader(.accessControlAllowOrigin, value: "*")
    response.setHeader(.accessControlAllowHeaders, value: "*")
    return response
}

func getExecutorLoadStatus(config: ExecutorConfiguration, timeout: Double = 30, handleCompletion: @escaping (Float) -> Void) {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    let session = URLSession(configuration: configuration)
    
    let url = config.loadStatusUrl
    var request = URLRequest(url: url)
    print(url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")

    request.setValue(config.credentials, forHTTPHeaderField: "Authorization")
    
    // let parameters = ["username": "foo", "password": "123456"]
    
    // do {
    //     request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
    // } catch let error {
    //     print(error.localizedDescription)
    // }
    
    let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
        do {
            guard let unwrappedData = data else {
                throw EncodingError.cannotEncodeObject(message: "Cannot unwrap response data")
            }
            guard let json = try JSONSerialization.jsonObject(with: unwrappedData, options: []) as? [String: Any] else {
                throw EncodingError.cannotEncodeObject(message: "Cannot interpret json as a dictionary")
            }
            print("3")
            handleCompletion(
                ("\(json["value"] ?? "\(DEFAULT_LOAD_STATUS)")" as NSString).floatValue
            )
        } catch let error {
            print("Error occurred: \(error)")
            print("2")
            handleCompletion(DEFAULT_LOAD_STATUS)
        }
    })
    
    task.resume()
}

func executeExperiment(config: ExecutorConfiguration, timeout: Double = 30, params: [String: Any], handleCompletion: @escaping (String) -> Void) {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    let session = URLSession(configuration: configuration)
    
    let urlComponents = NSURLComponents(string: config.baseUrl.absoluteString)!

    urlComponents.queryItems = params.map{ (key, value) in
        URLQueryItem(name: key, value: "\(value)")
    }

    let url = urlComponents.url!
    
    var request = URLRequest(url: url)
    print(url)
    request.httpMethod = "GET"
    // request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // request.addValue("application/json", forHTTPHeaderField: "Accept")

    request.setValue(config.credentials, forHTTPHeaderField: "Authorization")
    // do {
    //     request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
    // } catch let error {
    //     print(error.localizedDescription)
    // }
    
    let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
        print(data, response, error)
        do {
            guard let unwrappedData = data else {
                throw EncodingError.cannotEncodeObject(message: "Cannot unwrap response data")
            }
            guard let json = try JSONSerialization.jsonObject(with: unwrappedData, options: []) as? [String: Any] else {
                throw EncodingError.cannotEncodeObject(message: "Cannot interpret json as a dictionary")
            }
            print("3")
            handleCompletion(
                "\(json["experiment-id"] ?? "")"
            )
        } catch let error {
            print("Error occurred: \(error)")
            print("2")
            handleCompletion("")
        }
    })
    
    task.resume()
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
public let experimentExecutors = [
    "link-prediction": [
        ExecutorConfiguration(url: "http://localhost:1719", login:"", password: "")
        // ExecutorConfiguration(url: "http://localhost:1721", login:"", password: "")
    ]
]
public let DEFAULT_LOAD_STATUS: Float = 10000

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
        do {
            let requestBody = request.postBody ?? [String: Any]()
            print("Starting an experiment with params: ")
            print(requestBody)

            // Select a free executor

            let experimentTypeName = "\(requestBody["type"] ?? "")"
            if let experimentExecutorUrls = experimentExecutors[experimentTypeName] {
                print("Found executors: \(experimentExecutorUrls)")
                
                let group = DispatchGroup()
                let loadStatusesLock = NSLock()
                var loadStatuses = [ExecutorConfiguration: Float]()
                
                experimentExecutorUrls.map{ config in
                    group.enter()
                    DispatchQueue.global(qos: .userInitiated).async {
                        getExecutorLoadStatus(config: config) { loadStatus in
                            print("entering...")
                            if loadStatus < DEFAULT_LOAD_STATUS {
                                loadStatusesLock.lock()
                                loadStatuses[config] = loadStatus
                                loadStatusesLock.unlock()
                            }
                            print("leaving...")
                            group.leave()
                        }
                    }
                }

                print("waiting...")
                group.wait()
                print("load statuses:")
                print(loadStatuses)

                if loadStatuses.count < 1 {
                    throw ExperimentError.executorsAreNotAvailable(message: "Cannot assign an executor")
                }

                let selectedExecutor = loadStatuses.min{foo, bar in foo.value < bar.value}!.key
                print("Selected executor: \(selectedExecutor)")

                var token = ""
                var tokenLock = NSLock()

                tokenLock.lock()

                executeExperiment(config: selectedExecutor, params: requestBody) { experimentId in
                    print("Experiment id: \(experimentId)")
                    token = experimentId
                    tokenLock.unlock()
                    // response.setHeader(.contentType, value: "application/json")
                    // response.appendBody(string: String(data: try! JSONEncoder().encode(["experiment-id": experimentId]), encoding: .utf8)!)
                }
                response.setHeader(.contentType, value: "application/json")
                tokenLock.lock()
                response.appendBody(string: String(data: try! JSONEncoder().encode(["experiment-id": token]), encoding: .utf8)!)
            } else {
                throw ExperimentError.executorsAreNotAvailable(message: "Cannot assign an executor")
            }
        } catch {
            response.setHeader(.contentType, value: "text/html")
            response.status = .internalServerError
            response.appendBody(string: "<html><title>Exception!</title><body>Experiment cannot be started</body></html>")
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
