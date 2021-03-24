//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation
import XCTest

@testable import FNMNetworkMonitor

class NetworkMonitorAppLaunchTests: NetworkMonitorUnitTests {

    func testAppLaunch() {

        let recordBuilder = DebugEnvironmentHelperRecordBuilder()

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        self.networkMonitor.configure(profiles: Constants.Sites.allCases.map { $0.profile })
        self.networkMonitor.clear(completion: { } )
        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring()
        FNMNetworkMonitor.shared.passiveExportPreference = .on(setting: .unlimited)

        let debugListingViewController = FNMDebugListingViewController()
        debugListingViewController.view.layoutIfNeeded()

        let robotsExpectation = expectation(description: "Some Robots")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { recordBuilder.recordProgress(.overall, dateType: .start) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { recordBuilder.recordProgress(.innerStep1, dateType: .start) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { recordBuilder.recordProgress(.innerStep1, dateType: .end) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {

            recordBuilder.recordProgress(.innerStep2, dateType: .start)

            self.reachSitesSequencially(sites: [.alphabet],
                                        completion: {})
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { recordBuilder.recordProgress(.innerStep2, dateType: .end) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {

            recordBuilder.recordProgress(.innerStep3, dateType: .start)

            self.reachSitesSequencially(sites: [.intel],
                                        completion: {})
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { recordBuilder.recordProgress(.innerStep3, dateType: .end) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { recordBuilder.recordProgress(.innerStep4, dateType: .start) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) { recordBuilder.recordProgress(.innerStep4, dateType: .end) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { recordBuilder.recordProgress(.overall, dateType: .end)

            self.commit(from: recordBuilder)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { robotsExpectation.fulfill() }
        }

        waitForExpectations(timeout: 60) { _ in

            /// The files arent decodable, so lets just check for the string count. We just want to make sure something is being written out
            XCTAssertGreaterThan(self.exportFileCount, 1000)
        }
    }
}

private extension NetworkMonitorAppLaunchTests {

    enum LaunchDateType: Int {

        case start
        case end
    }

    enum LaunchReportElement: Int {

        enum Constants {

            static let overall = "overall"
            static let innerStep1 = "innerStep1"
            static let innerStep2 = "innerStep2"
            static let innerStep3 = "innerStep3"
            static let innerStep4 = "innerStep4"
        }

        case overall
        case innerStep1
        case innerStep2
        case innerStep3
        case innerStep4

        func elementIdentifier() -> String {

            switch self {

            case .overall: return Constants.overall
            case .innerStep1: return Constants.innerStep1
            case .innerStep2: return Constants.innerStep2
            case .innerStep3: return Constants.innerStep3
            case .innerStep4: return Constants.innerStep4
            }
        }
    }

    class ElementBuilder {

        var identifier: String
        var start: Date?
        var end: Date?

        init(identifier: String) {

            self.identifier = identifier
        }

        func build() -> FNMElement? {

            guard let start = self.start, let end = self.end else {

                return nil
            }

            return FNMElement(identifier: self.identifier,
                                       start: start,
                                       end: end,
                                       subElements: [])
        }
    }

    class DebugEnvironmentHelperRecordBuilder: NSObject {

        var overall = ElementBuilder(identifier: LaunchReportElement.overall.elementIdentifier())
        var innerStep1 = ElementBuilder(identifier: LaunchReportElement.innerStep1.elementIdentifier())
        var innerStep2 = ElementBuilder(identifier: LaunchReportElement.innerStep2.elementIdentifier())
        var innerStep3 = ElementBuilder(identifier: LaunchReportElement.innerStep3.elementIdentifier())
        var innerStep4 = ElementBuilder(identifier: LaunchReportElement.innerStep4.elementIdentifier())

        func recordProgress(_ elementType: LaunchReportElement, dateType: LaunchDateType) {

            let date = Date()

            var element: ElementBuilder?

            switch elementType {

            case .overall:
                element = self.overall
            case .innerStep1:
                element = self.innerStep1
            case .innerStep2:
                element = self.innerStep2
            case .innerStep3:
                element = self.innerStep3
            case .innerStep4:
                element = self.innerStep4
            }

            switch dateType {
            case .start:
                element?.start = date
            case .end:
                element?.end = date
            }
        }
    }

    func commit(from recordBuilder: DebugEnvironmentHelperRecordBuilder) {

        guard let overall = recordBuilder.overall.build(),
            let innerStep1 = recordBuilder.innerStep1.build(),
            let innerStep2 = recordBuilder.innerStep2.build(),
            let innerStep3 = recordBuilder.innerStep3.build(),
            let innerStep4 = recordBuilder.innerStep4.build() else {

                assertionFailure("Cannot commit record with insufficient data")
                return
        }

        let requestNodesA: [FNMRequestNode] = FNMRequestNode.decodedElements(from: Bundle.main,
                                                                                      filename: Constants.requestNodesA)
        let requestNodesB: [FNMRequestNode] = FNMRequestNode.decodedElements(from: Bundle.main,
                                                                                      filename: Constants.requestNodesB)

        let timestamps = [ LaunchReportElement.Constants.overall: overall,
                           LaunchReportElement.Constants.innerStep1: innerStep1,
                           LaunchReportElement.Constants.innerStep2: innerStep2,
                           LaunchReportElement.Constants.innerStep3: innerStep3,
                           LaunchReportElement.Constants.innerStep4: innerStep4]

        let record = FNMRecord(version: "1.0.0",
                               freshInstall: false,
                               timestamps: timestamps,
                               requestCluster: (requestNodesA, requestNodesB))

        FNMNetworkMonitor.shared.exportData(record: record)
    }

    var exportFileCount: Int {

        do {

            let currentRunConfigurationFile = try String(contentsOf: FNMRecordExporter.currentRunConfigurationFilenameURL(),
                                                         encoding: .utf8)

            return currentRunConfigurationFile.count

        } catch {

            return 0
        }
    }
}
