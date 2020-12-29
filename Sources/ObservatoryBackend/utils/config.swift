import Foundation
import Yaml

private func readConfig() throws -> Yaml {
    let lines = try Yaml.load(read(path: "config.yml"))
    return lines
}

let env = ProcessInfo.processInfo.environment

let config = try! readConfig()
