//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

public typealias HTTPVerb = String
public typealias HTTPCode = Int

public enum FNMHTTPRequestRecordConclusionType {

    case clientError(error: NSError)
    case redirected(newRequest: NSURLRequest?)
    case completed(URLProtocolLoadState: FNMNetworkMonitorURLProtocolLoadState,
                   response: HTTPURLResponse?,
                   data: Data?)

    func displayRepresentation() -> String {

        switch self {
        case .clientError(let error):

            return "Client Error: \(error.localizedDescription)"

        case .redirected(let newRequest):

            guard let urlAbsoluteString = newRequest?.url?.absoluteString else { return "-" }
            return "Redirected: \(String(describing: urlAbsoluteString))"

        case .completed(_, let response, _):

            guard let statusCode = response?.statusCode else { return "-" }
            return "Completed: \(String(describing: statusCode))"
        }
    }
}

@objc
final public class FNMHTTPRequestRecord: NSObject {

    public let key: HTTPRequestRecordKey

    public let request: NSURLRequest
    public let startTimestamp: Date

    public var endTimestamp: Date?
    public var conclusion: FNMHTTPRequestRecordConclusionType?

    public var timeSpent: TimeInterval? {

        guard let endTimestamp = self.endTimestamp else { return nil }
        return endTimestamp.timeIntervalSince1970 - self.startTimestamp.timeIntervalSince1970
    }

    public var profile: FNMProfile? {

        return FNMProfile(record: self)
    }

    public init(key: HTTPRequestRecordKey,
                request: NSURLRequest,
                startTimestamp: Date) {

        self.key = key
        self.request = request
        self.startTimestamp = startTimestamp
    }

    public override var description: String {

        return "\(String(describing: self.request.httpMethod)) \(String(describing: self.request.url?.absoluteString)) at \(self.startTimestamp) got \(String(describing: self.conclusion)))"
    }
}
