//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

public struct FNMElement: Encodable {

    public let identifier: String
    public let start: Date
    public let end: Date
    public let subElements: [FNMElement]
    public var timeTotal: TimeInterval {

        return end.timeIntervalSince1970 - start.timeIntervalSince1970
    }

    public init(identifier: String, start: Date, end: Date, subElements: [FNMElement]) {

        self.identifier = identifier
        self.start = start
        self.end = end
        self.subElements = subElements
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {

        case identifier
        case start
        case end
        case subElements
        case timeTotal
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encodeIfPresent(self.start, forKey: .start)
        try container.encodeIfPresent(self.end, forKey: .end)
        try container.encodeIfPresent(self.timeTotal, forKey: .timeTotal)

        if self.subElements.count > 0 {

            try container.encode(self.subElements, forKey: .subElements)
        }
    }
}
