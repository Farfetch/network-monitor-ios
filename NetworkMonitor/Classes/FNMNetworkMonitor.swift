//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation
import UIKit

@objc
public protocol FNMNetworkMonitorObserver: AnyObject {

    func recordsUpdated(records: [FNMHTTPRequestRecord])
}

private class NetworkMonitorObserverWrapper: NSObject {

    weak var innerObserver: FNMNetworkMonitorObserver?
}

@objc
public final class FNMNetworkMonitor: NSObject {

    /// The shared instance that backs this class
    @objc
    public static let shared = FNMNetworkMonitor()

    /// The current log scope used for logging. Can be edited as needed
    public var logScope: FNMLogScope?

    /// Whether the passive export is enabled
    public var passiveExportPreference: FNMRecordExporterPreference = .off

    /// The current collection of records recorded so far
    @objc
    public private(set) var records = [HTTPRequestRecordKey: FNMHTTPRequestRecord]()

    /// The sum of all recorded request payload sizes
    public private(set) var totalRequestSize = 0

    /// The sum of all recorded response payload sizes
    public private(set) var totalResponseSize = 0

    /// The profiles used for record matching. Can be edited
    @objc
    public private(set) var profiles = [FNMProfile]()

    /// The current profile usage map.
    private(set) var profilesUsageMap = [String: UInt]()

    /// The observers
    private var observers = [NetworkMonitorObserverWrapper]()

    /// Interal queue for synchronizing record setting
    private let recordsSyncQueue = DispatchQueue(label: Constants.dispatchQueueName)

    /// Date used for internal logic
    let referenceDate = Date()

    var ignoredDomains: [String] = []

    /// Start monitoring the network
    @objc
    public func startMonitoring() {

        self.subscribe(observer: self)

        FNMNetworkMonitorURLProtocol.activate(dataSource: self)
    }

    /// Stop monitoring the network
    @objc
    public func stopMonitoring() {

        FNMNetworkMonitorURLProtocol.deactivate()
    }

    /// Checks whether the network is being monitored
    @objc
    public func isMonitoring() -> Bool {

        return FNMNetworkMonitorURLProtocol.active
    }

    /// Configure if media payload will be recorded (default is true)
    @objc
    public func recordMediaPayload(_ value: Bool) {

        FNMNetworkMonitorURLProtocol.recordMediaPayload = value
    }

    /// Reset the current state
    ///
    /// - Parameter completion: a completion
    @objc
    public func clear(completion: @escaping () -> (Void)) {

        self.recordsSyncQueue.async {

            self.records.removeAll()
            self.profilesUsageMap.removeAll()
            self.totalRequestSize = 0
            self.totalResponseSize = 0

            self.reportRecordsChange(completion: completion)
        }
    }

    /// Subscribe for state updates
    ///
    /// - Parameter observer: observer instance
    @objc
    public func subscribe(observer: FNMNetworkMonitorObserver) {

        self.observers = self.observers.filter { $0.innerObserver != nil }

        if self.observers.contains(where: { observer === $0.innerObserver }) == false {

            let wrapper = NetworkMonitorObserverWrapper()
            wrapper.innerObserver = observer

            self.observers.append(wrapper)
        }
    }

    /// Unsubscribe from state updates
    ///
    /// - Parameter observer: observer instance
    @objc
    public func unsubscribe(observer: FNMNetworkMonitorObserver) {

        if let index = self.observers.firstIndex(where: { observer === $0.innerObserver }) {

            self.observers.remove(at: index)
        }
    }

    /// Profile specific network requests
    @objc
    public func configure(profiles: [FNMProfile]) {

        assert(self.validate(profiles: profiles), "Profile responses contain duplicate identifiers, which is ilegal")

        self.profiles = profiles
    }

    /// Profile additional profiles
    @objc
    public func configure(additional profiles: [FNMProfile]) {

        var mutatedProfiles = self.profiles
        mutatedProfiles.append(contentsOf: profiles)

        self.configure(profiles: mutatedProfiles)
    }

    /// Remove a specific profile
    @objc
    public func deconfigure(profile: FNMProfile) {

        let mutatedProfiles = self.profiles.filter { $0 !== profile }

        self.configure(profiles: mutatedProfiles)
    }

    /// Reset all profiles
    @objc
    public func resetProfiles() {

        self.configure(profiles: [])
    }

    /// Export the data
    public func exportData(record: FNMRecord, overallRecords: Bool = false) {

        self.recordsSyncQueue.async {

            FNMRecordExporter.exportRecord(record, requestRecords: Array(self.records.values), overallRecords: overallRecords)
        }
    }

    /// Export the current record data
    @objc
    public func exportRecordData() {

        self.recordsSyncQueue.async {

            let localRecords = self.records
            let localRecordsSequence = Array(localRecords.values)

            FNMRecordExporter.export(localRecordsSequence,
                                     preference: self.passiveExportPreference)
        }
    }

    /// Show the debug listing view controller
    ///
    /// - Parameter presentingNavigationController: the navigation controller to present the UI
    @objc
    public func showDebugListingViewController(presentingNavigationController: UINavigationController?) {

        let debugListingViewController = FNMDebugListingViewController()

        presentingNavigationController?.pushViewController(debugListingViewController, animated: true)
    }

    /// Dismiss all view controllers
    ///
    /// - Parameter currentNavigationController: the navigation controller currently in the stack
    @objc
    public func dismissDebugListingViewController(currentNavigationController: UINavigationController?) {

        currentNavigationController?.dismiss(animated: true, completion: nil)
    }

    /// Attempts to register to the URL Loading Ssytem.
    /// Will be able to monitor requests made through the default system sessions
    @objc
    public static func registerToLoadingSystem() {

        URLProtocol.registerClass(FNMNetworkMonitorURLProtocol.self)
    }

    /// Attempts to unregister to the URL Loading Ssytem.
    @objc
    public static func unregisterToLoadingSystem() {

        URLProtocol.unregisterClass(FNMNetworkMonitorURLProtocol.self)
    }

    /// Normalized URLProtocols
    @objc
    public static func normalizedURLProtocols() -> [URLProtocol.Type] {

        return [FNMNetworkMonitorURLProtocol.self]
    }

    /// Convenience method for normalizing the URLProtocols of a Session Configuration
    ///
    /// - Parameter config: a config
    @objc(normalizeURLProtocolClassesForConfig:)
    public static func normalizeURLProtocolClasses(for config: URLSessionConfiguration) {

        var customProtocolClasses = config.protocolClasses?.filter { return $0 != FNMNetworkMonitorURLProtocol.self }

        customProtocolClasses?.insert(FNMNetworkMonitorURLProtocol.self,
                                      at: 0)

        config.protocolClasses = customProtocolClasses
    }

    @objc
    public func configure(ignoredDomains: [String]) {

        self.ignoredDomains = ignoredDomains
    }
}

private extension FNMNetworkMonitor {

    private enum Constants {

        static let dispatchQueueName = "NetworkMonitor.recordsSyncQueue"
    }

    private func reportRecordsChange(completion: @escaping HTTPRequestRecordSetterCompletion) {

        self.recordsSyncQueue.async {

            let localRecords = Array(self.records.values)

            DispatchQueue.main.async {

                completion()

                self.observers.forEach { (wrapper) in wrapper.innerObserver?.recordsUpdated(records: localRecords) }
            }
        }
    }
}

extension FNMNetworkMonitor {

    func validate(profiles: [FNMProfile]) -> Bool {

        let allResponses = profiles.compactMap { return $0.responses }.joined()
        let allIdentifiers = Set(allResponses.map { $0.identifier })

        return allIdentifiers.count == allResponses.count
    }
}

extension FNMNetworkMonitor: FNMNetworkMonitorURLProtocolDataSource {

    func shouldIgnoreRequest(with url: URL) -> Bool {

        self.ignoredDomains.contains(where: { url.absoluteString.contains($0) } )
    }

    func requestRecord(for key: HTTPRequestRecordKey) -> FNMHTTPRequestRecord? {

        return self.records[key]
    }

    func setRequestRecord(requestRecord: FNMHTTPRequestRecord,
                          completion: @escaping HTTPRequestRecordSetterCompletion) {

        self.recordsSyncQueue.async {

            self.records[requestRecord.key] = requestRecord
            self.totalRequestSize += requestRecord.requestSize
            self.totalResponseSize += requestRecord.responseSize

            self.reportRecordsChange(completion: completion)
        }
    }

    func availableProfiles() -> [FNMProfile] {

        return self.profiles
    }

    func availableProfileResponseAllowable() -> FNMProfileResponseAllowable {

        return {

            guard case let .limited(numberOfUsesTotal) = $0.repeatability else { return true }

            let currentUses = self.profilesUsageMap[$0.identifier] ?? 0

            return currentUses < numberOfUsesTotal
        }
    }

    func bumpUses(for profileResponseIdentifier: String) {

        let currentUses = self.profilesUsageMap[profileResponseIdentifier] ?? 0

        self.profilesUsageMap[profileResponseIdentifier] = currentUses + 1
    }
}

extension FNMNetworkMonitor: FNMNetworkMonitorObserver {

    public func recordsUpdated(records: [FNMHTTPRequestRecord]) {

        guard case FNMRecordExporterPreference.on(_) = self.passiveExportPreference,
            records.filter({ $0.conclusion == nil }).count == 0 else { return }

        self.exportRecordData()
    }
}
