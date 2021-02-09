//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

extension FNMHTTPRequestRecord: NSCopying {

    public func copy(with zone: NSZone? = nil) -> Any {

        let copy = FNMHTTPRequestRecord(key: self.key,
                                     request: self.request,
                                     startTimestamp: self.startTimestamp)

        copy.endTimestamp = self.endTimestamp
        copy.conclusion = self.conclusion

        return copy
    }
}

extension FNMHTTPRequestRecord: Encodable {

    enum CodingKeys: String, CodingKey {

        case identifier = "identifier"
        case request = "request"
        case conclusion = "response"
        case startTimestamp = "startedAt"
        case endTimestamp = "endedAt"
        case timeSpent = "timeSpent"
        case profile = "profile"
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.key, forKey: .identifier)
        try container.encode(self.request.displayRepresentation(), forKey: .request)
        try container.encode(self.startTimestamp, forKey: .startTimestamp)
        try container.encode(self.endTimestamp, forKey: .endTimestamp)
        try container.encode(self.conclusion?.displayRepresentation(), forKey: .conclusion)
        try container.encode(self.timeSpent, forKey: .timeSpent)
        try container.encode(self.profile, forKey: .profile)
    }
}

extension NSURLRequest {

    func displayRepresentation() -> String {

        guard let httpMethod = self.httpMethod,
            let urlAbsoluteString = self.url?.absoluteString else { return "-" }

        return "\(String(describing: httpMethod)) \(String(describing: urlAbsoluteString))"
    }
}
