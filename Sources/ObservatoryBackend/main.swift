import ArgumentParser
import PerfectHTTP
import PerfectHTTPServer
import StORM
import MongoDBStORM
import Foundation
import FoundationNetworking

public let USERS_COLLECTION_NAME = "test-users"
public let EXPERIMENTS_COLLECTION_NAME = "test-experiments"
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
    internal var tokenLength: Int = 64

    @Option(help: "Set of characters which may occur in the tokens")
    var tokenCharset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    @Option(help: "Number of seconds for authentication tokens to be active")
    private var tokenMaxLifespan: Double = 604800 // 1 week

    func sendOptions(request: HTTPRequest, response: HTTPResponse) {
        response.completed()
    }

    func isAuthenticated(request: HTTPRequest, response: HTTPResponse) {
        response.completed()
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
        routes.add(method: .get, uri: "/get-experiment", handler: queryExperiment)
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
