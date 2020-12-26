// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ObservatoryBackend",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .branch("main")),
        // .package(url: "https://github.com/apple/swift-log.git", .branch("main")),
        .package(name: "PerfectHTTPServer", url: "https://github.com/zeionara/Perfect-HTTPServer.git", .branch("master")),
        .package(name: "MongoDBStORM", url: "https://github.com/zeionara/MongoDB-StORM.git", .branch("master"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ObservatoryBackend",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                // .product(name: "Logging", package: "swift-log"),
                .product(name: "PerfectHTTPServer", package: "PerfectHTTPServer"),
                .product(name: "MongoDBStORM", package: "MongoDBStORM")
            ]
        ),
        .testTarget(
            name: "ObservatoryBackendTests",
            dependencies: ["ObservatoryBackend"]
        )
    ]
)
