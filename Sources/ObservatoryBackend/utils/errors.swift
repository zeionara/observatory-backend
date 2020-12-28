enum AuthenticationError: Error {
    case cannotAuthenticate(message: String)
}

enum ExperimentError: Error {
    case executorsAreNotAvailable(message: String)
    case invalidExperimentArguments(message: String)
    case cannotFindExperiment(message: String)
}

enum EncodingError: Error {
    case cannotEncodeObject(message: String)
}
