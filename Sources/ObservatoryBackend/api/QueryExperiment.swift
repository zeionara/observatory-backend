import PerfectHTTP
import Foundation
import PerfectMongoDB
import MongoDBStORM
import StORM

public extension HTTPResponse {
    func appendBody(_ body: [String: Any]) throws {
        let jsonObject = try? JSONSerialization.data(withJSONObject: body, options: [])
        if let jsonString = String(data: jsonObject!, encoding: .utf8) {
            self.appendBody(string: jsonString)
        } else {
            throw EncodingError.cannotEncodeObject(message: "Cannot transform dictionary into json string")
        }
    }
}

public extension Array where Element == (String, Any) {
    var asDict: [String: Any]{
        return self.reduce([:]) {
            var dict: [String: Any] = $0
            dict[$1.0] = $1.1   
            return dict
        }
    }
}

extension StartServer {
    func queryExperiment(request: HTTPRequest, response: HTTPResponse) {
        response.setHeader(.contentType, value: "application/json")
        do {
            if let unwrappedType = request.param(name: "experiment-id") {
                let stringifiedType = "\(unwrappedType)"

                let experiment = Experiment()
                try experiment.get(stringifiedType)

                if experiment.id.isEmpty {
                    throw ExperimentError.cannotFindExperiment(message: "No experiment with id \(stringifiedType)")
                }

                try response.appendBody(experiment.asData().asDict)
            } else {
                throw ExperimentError.cannotFindExperiment(message: "No id provided")
            }
        } catch {
            response.status = .internalServerError
            response.appendBody(["error": error.localizedDescription])
        }
        response.completed()
    }

    func queryExperiments(request: HTTPRequest, response: HTTPResponse) {
        response.setHeader(.contentType, value: "application/json")
        do {
            if let unwrappedType = request.param(name: "type") {
                let stringifiedType = "\(unwrappedType)"
                try response.appendBody(["items": try Experiment.findAll().filter{$0.task == stringifiedType}.map{$0.asDataDict()}])
            } else {
                throw ExperimentError.cannotFindExperiment(message: "No id provided")
            }
        } catch {
            response.status = .internalServerError
            response.appendBody(["error": error.localizedDescription])
        }
        response.completed()
    }
}
