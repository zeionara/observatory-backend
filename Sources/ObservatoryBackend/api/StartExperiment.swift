import PerfectHTTP
import Foundation

extension StartServer {
    func startExperiment(request: HTTPRequest, response: HTTPResponse) {
        response.setHeader(.contentType, value: "application/json")
        do {
            let requestBody = request.postBody ?? [String: Any]()
            let selectedExecutor = try selectExecutor(requestBody)
        
            var experimentId: String? = Optional.none
            let tokenLock = NSLock()

            tokenLock.lock()

            executeExperiment(config: selectedExecutor, params: requestBody) { generatedExperimentId in
                experimentId = generatedExperimentId
                tokenLock.unlock()
            }

            tokenLock.lock()
            if let unwrappedExperimentId = experimentId {
                response.appendBody(["experiment-id": unwrappedExperimentId])
            } else {
                throw ExperimentError.invalidExperimentArguments(message: "Provided parameter values are not correct")
            }
        } catch {
            response.status = .internalServerError
            response.appendBody(["error": error.localizedDescription])
        }
        response.completed()
    }
}