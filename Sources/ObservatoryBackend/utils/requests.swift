import FoundationNetworking
import Foundation
import PerfectHTTP
import Logging

private func executeQuery(request: URLRequest, timeout: Double = 30, defaultResult: String = "", loggingLevel: Logger.Level = .debug, handleCompletion: @escaping ([String: Any]?) -> Void) {
    let logger = Logger("query-executor", loggingLevel)
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    let session = URLSession(configuration: configuration)
    
    let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
        do {
            guard let unwrappedData = data else {
                throw EncodingError.cannotEncodeObject(message: "Cannot unwrap response data")
            }
            guard let json = try JSONSerialization.jsonObject(with: unwrappedData, options: []) as? [String: Any] else {
                throw EncodingError.cannotEncodeObject(message: "Cannot interpret json as a dictionary")
            }
            handleCompletion(
                json
            )
        } catch let error {
            logger.error("Error during query execution: \(error)")
            handleCompletion(
                Optional.none
            )
        }
    })
    task.resume()
}

public func getExecutorLoadStatus(config: ExecutorConfiguration, timeout: Double = 30, loggingLevel: Logger.Level = .debug, handleCompletion: @escaping (Float) -> Void) {
    var request = URLRequest(url: config.loadStatusUrl)
    let logger = Logger("executor-load-status-checker", loggingLevel)

    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(config.credentials, forHTTPHeaderField: "Authorization")
    
    executeQuery(request: request, timeout: timeout, loggingLevel: loggingLevel) { json in
        logger.debug("Handling load status response...")
        if let unwrappedJson = json {
            logger.debug("Calling completion handler...")
            handleCompletion(("\(unwrappedJson["value"] ?? "\(DEFAULT_LOAD_STATUS)")" as NSString).floatValue)
        } else {
            logger.debug("Calling completion handler...")
            handleCompletion(DEFAULT_LOAD_STATUS)
        }
    }
}

public func executeExperiment(config: ExecutorConfiguration, timeout: Double = 30, params: [String: Any], handleCompletion: @escaping (String?) -> Void) {
    let urlComponents = NSURLComponents(string: config.baseUrl.absoluteString)!

    urlComponents.queryItems = params.map{ (key, value) in
        URLQueryItem(name: key, value: "\(value)")
    }
    
    var request = URLRequest(url: urlComponents.url!)
    request.httpMethod = "GET"
    request.setValue(config.credentials, forHTTPHeaderField: "Authorization")
    
    executeQuery(request: request, timeout: timeout) { json in
        if let unwrappedJson = json {
            if let unwrappedExperimentId = unwrappedJson["experiment-id"] {
                handleCompletion("\(unwrappedExperimentId)")
            } else {
                handleCompletion(Optional.none)
            }
        } else {
            handleCompletion(Optional.none)
        }
    }
}

extension HTTPRequest {
    public var postBody: [String: AnyObject]? {
        return convertStringToDictionary(text: postBodyString ?? "")
    }
}
