import PerfectHTTP
import Foundation
import Logging

public let experimentExecutors = config["executors"].dictionary!.reduce([String: [ExecutorConfiguration]]()) { (dict, pair) -> [String: [ExecutorConfiguration]] in
    var dict = dict
    dict[pair.key.string ?? ""] = pair.value.array!.map{config in
        ExecutorConfiguration(
            url: config["url"].string!, login: config["login"].string!, password: config["password"].string!
        )
    }
    return dict
}

public func selectExecutor(_ requestBody: [String: Any], loggingLevel: Logger.Level) throws -> ExecutorConfiguration {
    let logger = Logger("experiment-starter", loggingLevel)
    let experimentTypeName = "\(requestBody["task"] ?? "")"
    if let experimentExecutorConfigs = experimentExecutors[experimentTypeName] {
        let group = DispatchGroup()
        let loadStatusesLock = NSLock()
        var loadStatuses = [ExecutorConfiguration: Float]()
        
        for config in experimentExecutorConfigs {
            logger.debug("Entering group...")
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                getExecutorLoadStatus(config: config, loggingLevel: loggingLevel) { loadStatus in
                    logger.debug("Saving fetched load status for executor \(config.baseUrl)...")
                    if loadStatus < DEFAULT_LOAD_STATUS {
                        loadStatusesLock.lock()
                        loadStatuses[config] = loadStatus
                        loadStatusesLock.unlock()
                    }
                    logger.debug("Leaving group...")
                    group.leave()
                }
            }
        }

        group.wait()

        if loadStatuses.count < 1 {
            throw ExperimentError.executorsAreNotAvailable(message: "Cannot assign an executor")
        }

        return loadStatuses.min{foo, bar in foo.value < bar.value}!.key
    } else {
        throw ExperimentError.executorsAreNotAvailable(message: "Cannot assign an executor")
    }
}
