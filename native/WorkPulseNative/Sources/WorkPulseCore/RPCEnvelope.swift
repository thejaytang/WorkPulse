import Foundation

public enum RPCRequestID: Hashable, Sendable {
    case integer(Int64)
    case string(String)
}

public enum RPCEnvelopeKind: Equatable, Sendable {
    case response(id: RPCRequestID, isError: Bool)
    case serverRequest(id: RPCRequestID, method: String)
    case notification(method: String)
}

public enum RPCEnvelopeError: Error, Equatable, Sendable {
    case invalidJSON
    case invalidEnvelope
    case invalidRequestID
}

public enum RPCEnvelopeClassifier {
    public static func classify(_ data: Data) throws -> RPCEnvelopeKind {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            throw RPCEnvelopeError.invalidJSON
        }

        let method = dictionary["method"] as? String
        let hasID = dictionary["id"] != nil && !(dictionary["id"] is NSNull)
        let hasResult = dictionary.keys.contains("result")
        let hasError = dictionary.keys.contains("error")

        if hasID, hasResult != hasError, method == nil {
            return .response(id: try requestID(dictionary["id"]), isError: hasError)
        }
        if hasID, let method, !hasResult, !hasError {
            return .serverRequest(id: try requestID(dictionary["id"]), method: method)
        }
        if !hasID, let method, !hasResult, !hasError {
            return .notification(method: method)
        }
        throw RPCEnvelopeError.invalidEnvelope
    }

    private static func requestID(_ value: Any?) throws -> RPCRequestID {
        if let value = value as? String, !value.isEmpty { return .string(value) }
        if let number = value as? NSNumber {
            let doubleValue = number.doubleValue
            let integerValue = number.int64Value
            guard doubleValue.isFinite, Double(integerValue) == doubleValue else {
                throw RPCEnvelopeError.invalidRequestID
            }
            return .integer(integerValue)
        }
        throw RPCEnvelopeError.invalidRequestID
    }
}

public enum AppServerSessionState: String, Equatable, Sendable {
    case stopped
    case starting
    case initializing
    case ready
    case backingOff
    case degraded
    case unsupported
}

public enum AppServerSessionTransition {
    public static func isAllowed(from: AppServerSessionState, to: AppServerSessionState) -> Bool {
        switch (from, to) {
        case (.stopped, .starting),
             (.starting, .initializing),
             (.starting, .degraded),
             (.initializing, .ready),
             (.initializing, .unsupported),
             (.initializing, .degraded),
             (.ready, .backingOff),
             (.ready, .stopped),
             (.backingOff, .starting),
             (.backingOff, .stopped),
             (.degraded, .backingOff),
             (.degraded, .stopped),
             (.unsupported, .stopped):
            true
        default:
            false
        }
    }
}
