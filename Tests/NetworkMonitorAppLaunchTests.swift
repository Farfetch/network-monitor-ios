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

        let appLaunchRecordBuilder = FFSDebugEnvironmentHelperAppLaunchRecordBuilder()

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        self.networkMonitor.configure(profiles: Constants.Sites.allCases.map { $0.profile })
        self.networkMonitor.clear(completion: { } )
        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring(passiveExport: true)

        let debugListingViewController = FNMDebugListingViewController()
        debugListingViewController.view.layoutIfNeeded()

        let robotsExpectation = expectation(description: "Some Robots")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { appLaunchRecordBuilder.recordProgress(.overall, dateType: .start) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { appLaunchRecordBuilder.recordProgress(.firstPartyFramework, dateType: .start) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { appLaunchRecordBuilder.recordProgress(.firstPartyFramework, dateType: .end) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {

            appLaunchRecordBuilder.recordProgress(.thirdPartyFramework, dateType: .start)

            self.reachSitesSequencially(sites: [.alphabet],
                                        completion: {})
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { appLaunchRecordBuilder.recordProgress(.thirdPartyFramework, dateType: .end) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {

            appLaunchRecordBuilder.recordProgress(.firstPartyAPISetup, dateType: .start)

            self.reachSitesSequencially(sites: [.intel],
                                        completion: {})
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { appLaunchRecordBuilder.recordProgress(.firstPartyAPISetup, dateType: .end) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { appLaunchRecordBuilder.recordProgress(.uiSetup, dateType: .start) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) { appLaunchRecordBuilder.recordProgress(.uiSetup, dateType: .end) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { appLaunchRecordBuilder.recordProgress(.overall, dateType: .end)

            self.commitAppLaunch(from: appLaunchRecordBuilder)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { robotsExpectation.fulfill() }
        }

        waitForExpectations(timeout: 60) { _ in

            /// The files arent decodable, so lets just check for the string count. We just want to make sure something is being written out
            XCTAssertGreaterThan(self.exportFileCount, 1000)
        }
    }
}

private extension NetworkMonitorAppLaunchTests {

    enum FFSLaunchDateType: Int {

        case start
        case end
    }

    enum FFSLaunchReportElement: Int {

        private enum Constants {

            static let overall = "overall"
            static let thirdPartyFramework = "thirdPartyFramework"
            static let firstPartyFramework = "firstPartyFramework"
            static let firstPartyAPISetup = "firstPartyAPISetup"
            static let uiSetup = "uiSetup"
        }

        case overall
        case thirdPartyFramework
        case firstPartyFramework
        case firstPartyAPISetup
        case uiSetup

        func elementIdentifier() -> String {

            switch self {

            case .overall: return Constants.overall
            case .thirdPartyFramework: return Constants.thirdPartyFramework
            case .firstPartyFramework: return Constants.firstPartyFramework
            case .firstPartyAPISetup: return Constants.firstPartyAPISetup
            case .uiSetup: return Constants.uiSetup
            }
        }
    }

    class FFSAppLaunchElementBuilder {

        var identifier: String
        var start: Date?
        var end: Date?

        init(identifier: String) {

            self.identifier = identifier
        }

        func build() -> FNMAppLaunchElement? {

            guard let start = self.start, let end = self.end else {

                return nil
            }

            return FNMAppLaunchElement(identifier: self.identifier,
                                       start: start,
                                       end: end,
                                       subElements: [])
        }
    }

    class FFSDebugEnvironmentHelperAppLaunchRecordBuilder: NSObject {

        var overall = FFSAppLaunchElementBuilder(identifier: FFSLaunchReportElement.overall.elementIdentifier())
        var thirdPartyFrameworkSetup = FFSAppLaunchElementBuilder(identifier: FFSLaunchReportElement.thirdPartyFramework.elementIdentifier())
        var firstPartyFrameworkSetup = FFSAppLaunchElementBuilder(identifier: FFSLaunchReportElement.firstPartyFramework.elementIdentifier())
        var firstPartyAPISetup = FFSAppLaunchElementBuilder(identifier: FFSLaunchReportElement.firstPartyAPISetup.elementIdentifier())
        var uiSetup = FFSAppLaunchElementBuilder(identifier: FFSLaunchReportElement.uiSetup.elementIdentifier())

        func recordProgress(_ elementType: FFSLaunchReportElement, dateType: FFSLaunchDateType) {

            let date = Date()

            var element: FFSAppLaunchElementBuilder?

            switch elementType {

            case .overall:
                element = self.overall
            case .thirdPartyFramework:
                element = self.thirdPartyFrameworkSetup
            case .firstPartyFramework:
                element = self.firstPartyFrameworkSetup
            case .firstPartyAPISetup:
                element = self.firstPartyAPISetup
            case .uiSetup:
                element = self.uiSetup
            }

            switch dateType {
            case .start:
                element?.start = date
            case .end:
                element?.end = date
            }
        }
    }

    func commitAppLaunch(from appLaunchRecordBuilder: FFSDebugEnvironmentHelperAppLaunchRecordBuilder) {

        guard let overall = appLaunchRecordBuilder.overall.build(),
            let thirdPartyFrameworkSetup = appLaunchRecordBuilder.thirdPartyFrameworkSetup.build(),
            let firstPartyFrameworkSetup = appLaunchRecordBuilder.firstPartyFrameworkSetup.build(),
            let firstPartyAPISetup = appLaunchRecordBuilder.firstPartyAPISetup.build(),
            let uiSetup = appLaunchRecordBuilder.uiSetup.build() else {

                assertionFailure("Cannot commit app launch record with insufficient data")
                return
        }

        let firstPartyRequestNodes: [FNMAppLaunchRequestNode] = FNMAppLaunchRequestNode.decodedElements(from: Bundle.main,
                                                                                                        filename: Constants.coldStartFirstPartyCallsFilename)
        let thirdPartyRequestNodes: [FNMAppLaunchRequestNode] = FNMAppLaunchRequestNode.decodedElements(from: Bundle.main,
                                                                                                        filename: Constants.coldStartThirdPartyCallsFilename)

        let appLaunchTimestamps = FNMAppLaunchTimestamps(overall: overall,
                                                         thirdPartyFrameworkSetup: thirdPartyFrameworkSetup,
                                                         firstPartyFrameworkSetup: firstPartyFrameworkSetup,
                                                         firstPartyAPISetup: firstPartyAPISetup,
                                                         uiSetup: uiSetup)

        let appLaunchRecord = FNMAppLaunchRecord(version: "1.0.0",
                                                 freshInstall: false,
                                                 timestamps: appLaunchTimestamps,
                                                 requestCluster: (firstPartyRequestNodes, thirdPartyRequestNodes))

        FNMNetworkMonitor.shared.exportLaunchData(appLaunchRecord: appLaunchRecord)
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
