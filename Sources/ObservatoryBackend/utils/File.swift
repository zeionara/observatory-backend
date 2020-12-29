import Foundation

public func read(path: String) throws -> String {
    let dir = URL(fileURLWithPath: #file.replacingOccurrences(of: "Sources/ObservatoryBackend/utils/File.swift", with: ""))
    return try String(
            contentsOf: dir.appendingPathComponent(path),
            encoding: .utf8
    )
}
