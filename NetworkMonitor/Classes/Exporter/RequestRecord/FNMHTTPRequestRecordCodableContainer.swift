//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

struct FNMHTTPRequestRecordCodableContainer {

    let records: [FNMHTTPRequestRecord]

    init(records: [FNMHTTPRequestRecord]) {

        self.records = type(of: self).sorted(records: records)
    }
}

private extension FNMHTTPRequestRecordCodableContainer {

    var totalRecords: Int {

        return records.count
    }

    var totalTimeSpend: TimeInterval {

        return type(of: self).totalTimeSpend(from: records)
    }
}

private extension FNMHTTPRequestRecordCodableContainer {

    static func sorted(records: [FNMHTTPRequestRecord]) -> [FNMHTTPRequestRecord] {

        return records.sorted {

            return $0.startTimestamp.timeIntervalSince1970 < $1.startTimestamp.timeIntervalSince1970
        }
    }

    static func totalTimeSpend(from records: [FNMHTTPRequestRecord]) -> TimeInterval {

        return records.reduce(0.0) {

            guard let timeSpent = $1.timeSpent else { return $0 }
            return $0 + timeSpent
        }
    }
}

extension FNMHTTPRequestRecordCodableContainer: Encodable {

    enum CodingKeys: String, CodingKey {

        case records
        case totalRecords
        case totalTimeSpend
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.totalRecords, forKey: .totalRecords)
        try container.encode(self.totalTimeSpend, forKey: .totalTimeSpend)
        try container.encode(self.records, forKey: .records)
    }
}
