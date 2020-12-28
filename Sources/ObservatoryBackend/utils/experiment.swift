import PerfectHTTP
import Foundation

public let experimentExecutors = [
    "link-prediction": [
        ExecutorConfiguration(url: "http://localhost:1719", login:"", password: ""),
        ExecutorConfiguration(url: "http://localhost:1721", login:"", password: "")
    ]
]

public func selectExecutor(_ requestBody: [String: Any]) throws -> ExecutorConfiguration {
    let experimentTypeName = "\(requestBody["type"] ?? "")"
    if let experimentExecutorConfigs = experimentExecutors[experimentTypeName] {
        let group = DispatchGroup()
        let loadStatusesLock = NSLock()
        var loadStatuses = [ExecutorConfiguration: Float]()
        
        for config in experimentExecutorConfigs {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                getExecutorLoadStatus(config: config) { loadStatus in
                    if loadStatus < DEFAULT_LOAD_STATUS {
                        loadStatusesLock.lock()
                        loadStatuses[config] = loadStatus
                        loadStatusesLock.unlock()
                    }
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
