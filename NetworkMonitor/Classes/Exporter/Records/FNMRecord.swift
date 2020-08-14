//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

public typealias FNMRequestCluster = (firstPartyNodes: [FNMRequestNode], thirdPartyNodes: [FNMRequestNode])

final public class FNMRecord: NSObject {

    public let version: String
    public let freshInstall: Bool
    public let timestamps: [String: FNMElement]
    public let requestCluster: FNMRequestCluster?

    required public init(version: String,
                         freshInstall: Bool,
                         timestamps: [String: FNMElement],
                         requestCluster: FNMRequestCluster? = nil) {

        self.version = version
        self.freshInstall = freshInstall
        self.timestamps = timestamps
        self.requestCluster = requestCluster
    }
}

extension FNMRecord: Encodable {

    enum CodingKeys: String, CodingKey {

        case version
        case freshInstall
        case timestamps
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.version, forKey: .version)
        try container.encode(self.freshInstall, forKey: .freshInstall)
        try container.encode(self.timestamps, forKey: .timestamps)
    }
}
