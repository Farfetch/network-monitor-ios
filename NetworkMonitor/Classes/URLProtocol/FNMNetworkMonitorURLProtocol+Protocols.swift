//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation

typealias HTTPRequestRecordSetterCompletion = () -> (Void)
public typealias HTTPRequestRecordKey = String

protocol FNMNetworkMonitorURLProtocolDataSourceRecord {

    func requestRecord(for key: HTTPRequestRecordKey) -> FNMHTTPRequestRecord?
    func shouldIgnoreRequest(with url: URL) -> Bool

    func setRequestRecord(requestRecord: FNMHTTPRequestRecord,
                          completion: @escaping HTTPRequestRecordSetterCompletion)
}

protocol FNMNetworkMonitorURLProtocolDataSourceProfile {

    func availableProfiles(sorted: Bool) -> [FNMProfile]

    func availableProfileResponseAllowable() -> FNMProfileResponseAllowable

    func bumpUses(for profileResponseIdentifier: String)
}

extension FNMNetworkMonitorURLProtocolDataSourceProfile {

    func availableProfiles(sorted: Bool = false) -> [FNMProfile] {

        return self.availableProfiles(sorted: sorted)
    }
}

protocol FNMNetworkMonitorURLProtocolDataSource: AnyObject, FNMNetworkMonitorURLProtocolDataSourceRecord, FNMNetworkMonitorURLProtocolDataSourceProfile { }
