//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//
typealias HTTPRequestRecordSetterCompletion = () -> (Void)
public typealias HTTPRequestRecordKey = String

protocol FNMNetworkMonitorURLProtocolDataSourceRecord {

    func requestRecord(for key: HTTPRequestRecordKey) -> FNMHTTPRequestRecord?

    func setRequestRecord(requestRecord: FNMHTTPRequestRecord,
                          completion: @escaping HTTPRequestRecordSetterCompletion)
}

protocol FNMNetworkMonitorURLProtocolDataSourceProfile {

    func availableProfiles() -> [FNMProfile]

    func availableProfileResponseAllowable() -> FNMProfileResponseAllowable

    func bumpUses(for profileResponseIdentifier: String)
}

protocol FNMNetworkMonitorURLProtocolDataSource: class, FNMNetworkMonitorURLProtocolDataSourceRecord, FNMNetworkMonitorURLProtocolDataSourceProfile { }
