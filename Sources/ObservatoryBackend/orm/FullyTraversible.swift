public protocol FullyTraversible {
    associatedtype This
    static func findAll(_ data: [String: Any]) throws -> [This]
}
