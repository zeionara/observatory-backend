import FoundationNetworking
import Foundation

private func executeQuery(request: URLRequest, timeout: Double = 30, defaultResult: String = "", handleCompletion: @escaping ([String: Any]?) -> Void) {
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
            print("3")
            handleCompletion(
                json
            )
        } catch let error {
            print("Error occurred: \(error)")
            print("2")
            handleCompletion(
                Optional.none
            )
        }
    })
    task.resume()
}

public func getExecutorLoadStatus(config: ExecutorConfiguration, timeout: Double = 30, handleCompletion: @escaping (Float) -> Void) {
    var request = URLRequest(url: config.loadStatusUrl)
    
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(config.credentials, forHTTPHeaderField: "Authorization")
    
    executeQuery(request: request, timeout: timeout) { json in
        if let unwrappedJson = json {
            handleCompletion(("\(unwrappedJson["value"] ?? "\(DEFAULT_LOAD_STATUS)")" as NSString).floatValue)
        } else {
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
