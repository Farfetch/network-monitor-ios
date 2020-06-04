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

class NetworkMonitorExportTests: NetworkMonitorUnitTests {

    func testExportPassiveFiles() {

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        self.networkMonitor.configure(profiles: Constants.Sites.allCases.map { $0.profile })
        self.networkMonitor.clear(completion: { } )
        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring(passiveExport: true)

        let robotsExpectation = expectation(description: "Some Robots")
        self.reachSitesSequencially(sites: [.alphabet, .intel]) {

            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {

                let exportFiles = self.exportPassiveFiles

                /// The files arent decodable, so lets just check for the string count. We just want to make sure something is being written out
                XCTAssertLessThan(exportFiles.startTimestampRecordsFileCount, 1000)
                XCTAssertLessThan(exportFiles.alphaRecordsFileCount, 1000)
                XCTAssertLessThan(exportFiles.slowestRecordsFileCount, 1000)

                self.reachSitesSequencially(sites: [.amazon, .netflix]) {

                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {

                        let exportFiles = self.exportPassiveFiles

                        /// The files arent decodable, so lets just check for the string count. We just want to make sure something is being written out
                        XCTAssertGreaterThan(exportFiles.startTimestampRecordsFileCount, 100)
                        XCTAssertGreaterThan(exportFiles.alphaRecordsFileCount, 1000)
                        XCTAssertGreaterThan(exportFiles.slowestRecordsFileCount, 1000)

                        robotsExpectation.fulfill()
                    }
                }
            }
        }

        waitForExpectations(timeout: 60) { _ in }
    }

    func testExportActiveFiles() {

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        self.networkMonitor.configure(profiles: Constants.Sites.allCases.map { $0.profile })
        self.networkMonitor.clear(completion: { } )
        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring(passiveExport: true)

        let robotsExpectation = expectation(description: "Some Robots")
        self.reachSitesSequencially(sites: [.alphabet, .intel], expectation: robotsExpectation)

        waitForExpectations(timeout: 60) { _ in

            let records = self.networkMonitor.records.values.sorted(by: { $0.startTimestamp < $1.startTimestamp })

            let exportFiles = self.exportActiveFiles(from: records)

            XCTAssertLessThan(exportFiles.recordsCount, 1000)
            XCTAssertGreaterThan(exportFiles.detailInfosCount, 1000)
        }
    }

    var exportPassiveFiles: (startTimestampRecordsFileCount: Int, alphaRecordsFileCount: Int, slowestRecordsFileCount: Int) {

        do {

            let startTimestampRecordsFile = try String(contentsOf: FNMRecordExporter.recordsFilenameURL(option: .sortedStartTimestamp),
                                                       encoding: .utf8)
            let alphaRecordsFile = try String(contentsOf: FNMRecordExporter.recordsFilenameURL(option: .sortedAlphabetically),
                                              encoding: .utf8)
            let slowestRecordsFile = try String(contentsOf: FNMRecordExporter.recordsFilenameURL(option: .sortedSlowest),
                                                encoding: .utf8)

            return (startTimestampRecordsFile.count, alphaRecordsFile.count, slowestRecordsFile.count)

        } catch {

            return (0, 0, 0)
        }
    }

    func exportActiveFiles(from records: [FNMHTTPRequestRecord]) -> (recordsCount: Int, detailInfosCount: Int) {

        do {

            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = .prettyPrinted

            return (try jsonEncoder.encode(records).count,
                    try jsonEncoder.encode(records.compactMap { return FNMRecordDetailInfo(record: $0) }).count)

        } catch {

            return (0, 0)
        }
    }
}

