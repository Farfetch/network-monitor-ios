//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

public struct FNMRequestNode {

    public enum FNMRequestNodeType: String, Codable {

        case blocking
        case nonBlocking
        case other
    }

    let identifier: String
    let nodeDescription: String
    let expressions: [NSRegularExpression]
    let type: FNMRequestNodeType
}

extension FNMRequestNode: Codable {

    enum CodingKeys: String, CodingKey {

        case identifier = "identifier"
        case nodeDescription = "description"
        case expressions = "request-expressions"
        case type = "type"
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.nodeDescription, forKey: .nodeDescription)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.expressions.map { $0.pattern }, forKey: .expressions)
    }

    public init(from decoder: Decoder) throws {

        let values = try decoder.container(keyedBy: CodingKeys.self)

        do {

            try self.init(identifier: values.decode(String.self, forKey: .identifier),
                          nodeDescription: values.decode(String.self, forKey: .nodeDescription),
                          expressions: values.decode([String].self, forKey: .expressions).computedRegularExpressions(),
                          type: values.decode(FNMRequestNodeType.self, forKey: .type))
        }
    }
}
