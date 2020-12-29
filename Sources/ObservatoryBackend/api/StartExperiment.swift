import PerfectHTTP
import Foundation
import Logging

extension StartServer {
    func startExperiment(request: HTTPRequest, response: HTTPResponse) {
        let logger = Logger("experiment-starter", loggingLevel)
        response.setHeader(.contentType, value: "application/json")
        do {
            let requestBody = request.postBody ?? [String: Any]()
            
            logger.info("Selecting executor...")
            
            let selectedExecutor = try selectExecutor(requestBody, loggingLevel: loggingLevel)
        
            logger.info("Selected executor \(selectedExecutor.baseUrl)")
            
            var experimentId: String? = Optional.none
            let tokenLock = NSLock()

            tokenLock.lock()

            logger.info("Starting experiment...")

            executeExperiment(config: selectedExecutor, params: requestBody) { generatedExperimentId in
                experimentId = generatedExperimentId
                tokenLock.unlock()
                logger.info("Started experiment \(experimentId ?? "")")
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