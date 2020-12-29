import Logging
import ArgumentParser

public extension Logger{
    init(_ label: String, _ level: Logger.Level) {
        self.init(label: label)
        self.logLevel = level
    }
}

extension Logger.Level: ExpressibleByArgument {}
