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

    init(records: [FNMHTTPRequestRecord],
         option: FNMRecordExporterSortOption) {

        self.records = type(of: self).sorted(records: records,
                                             option: option)
    }
}

private extension FNMHTTPRequestRecordCodableContainer {

    var totalRecords: Int {

        return records.count
    }

    var totalTimeSpend: TimeInterval {

        return type(of: self).totalTimeSpend(from: records)
    }

    var availableProfiles: [FNMProfile] {

        return records.compactMap { return FNMProfile(record: $0) }
    }

}

private extension FNMHTTPRequestRecordCodableContainer {

    static func sorted(records: [FNMHTTPRequestRecord],
                       option: FNMRecordExporterSortOption) -> [FNMHTTPRequestRecord] {

        switch option {
        case .sortedAlphabetically:

            return records.sorted {

                guard let recordAAbsoluteURL = $0.request.url?.absoluteString,
                    let recordAScheme = $0.request.url?.scheme,
                    let recordBAbsoluteURL = $1.request.url?.absoluteString,
                    let recordBScheme = $1.request.url?.scheme else { return false }

                // The scheme is not relevant for this sort
                let recordATrimmedURL = recordAAbsoluteURL.replacingOccurrences(of: recordAScheme, with: "")
                let recordBTrimmedURL = recordBAbsoluteURL.replacingOccurrences(of: recordBScheme, with: "")

                return recordATrimmedURL.compare(recordBTrimmedURL) == .orderedAscending
            }

        case .sortedSlowest:

            return records.sorted {

                guard let recordATimeSpent = $0.timeSpent,
                    let recordBTimeSpent = $1.timeSpent else { return false }

                return recordATimeSpent > recordBTimeSpent
            }

        case .sortedStartTimestamp:

            return records.sorted {

                return $0.startTimestamp.timeIntervalSince1970 < $1.startTimestamp.timeIntervalSince1970
            }
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
        case availableProfiles
        case totalRecords
        case totalTimeSpend
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.totalRecords, forKey: .totalRecords)
        try container.encode(self.totalTimeSpend, forKey: .totalTimeSpend)
        try container.encode(self.records, forKey: .records)
        try container.encode(self.availableProfiles, forKey: .availableProfiles)
    }
}
