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

class NetworkMonitorDebugUITests: NetworkMonitorUnitTests {

    func testListing() {

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring()

        let debugListingViewController = FNMDebugListingViewController()
        debugListingViewController.view.layoutIfNeeded()

        let robotsExpectation = expectation(description: "Some Robots")
        self.reachSitesSequencially(expectation: robotsExpectation)

        waitForExpectations(timeout: 60) { _ in

            XCTAssertEqual(self.networkMonitor.records.count, Constants.Sites.allCases.count)
            XCTAssertEqual(debugListingViewController.allRecords.count, Constants.Sites.allCases.count)
            XCTAssertEqual(debugListingViewController.tableView(debugListingViewController.tableView, numberOfRowsInSection: 0), Constants.Sites.allCases.count)
        }
    }

    func testDetail() throws {

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        self.networkMonitor.configure(profiles: Constants.Sites.allCases.map { $0.profile })
        self.networkMonitor.clear(completion: { } )
        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring()

        let robotsExpectation = expectation(description: "Some Robots")
        self.reachSitesSequencially(sites: [.alphabet], expectation: robotsExpectation)

        waitForExpectations(timeout: 60) { _ in

            if let record = self.networkMonitor.records.values.first {

                let debugDetailViewController = FNMDebugDetailViewController(record: record)
                debugDetailViewController.view.layoutIfNeeded()
                debugDetailViewController.headersViewController.view.layoutIfNeeded()
                debugDetailViewController.requestBodyViewController.view.layoutIfNeeded()
                debugDetailViewController.responseBodyViewController.view.layoutIfNeeded()

                XCTAssertEqual(self.networkMonitor.records.count, 1)
                XCTAssertEqual(debugDetailViewController.requestBodyViewController.recordBodyDetailInfo.body.title, "Request Body")
                XCTAssertEqual(debugDetailViewController.requestBodyViewController.recordBodyDetailInfo.body.subtitle, "N/A")
                XCTAssertEqual(debugDetailViewController.headersViewController.recordHeaderDetailInfo.requestHeaders.first?.title, "HeaderA")
                XCTAssertEqual(debugDetailViewController.headersViewController.recordHeaderDetailInfo.requestHeaders.first?.subtitle, "ValueA")
                XCTAssertEqual(debugDetailViewController.responseBodyViewController.recordBodyDetailInfo.body.title, "Response")
                XCTAssertEqual(debugDetailViewController.responseBodyViewController.recordBodyDetailInfo.body.subtitle, """
                {
                    fieldA = valueA;
                    fieldB = valueB;
                }
                ""","")

            } else {

                XCTFail("Should have record")
            }
        }
    }
}
