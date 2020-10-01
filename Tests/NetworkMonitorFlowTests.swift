//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import XCTest

@testable import FNMNetworkMonitor

extension XCTestCase {

    enum Constants {

        static let genericProfilesFilename = "Generic-Profiles"
        static let genericProfilesDuplicatedFilename = "Generic-Profiles-Duplicates"
        static let genericProfilesResponseFilename = "Generic-Profile-Response"

        static let matchingProfiles1Filename = "Matching-Profiles-1"
        static let matchingProfiles2Filename = "Matching-Profiles-2"
        static let matchingProfiles3Filename = "Matching-Profiles-3"

        static let coldStartFirstPartyCallsFilename = "Cold-Start-First-Party-Calls"
        static let coldStartThirdPartyCallsFilename = "Cold-Start-Third-Party-Calls"

        static let blackImageFilename = "Image"

        static let jsonFileExtension = "json"
        static let pngFileExtension = "png"

        enum Sites: String, CaseIterable {

            case alphabet = "https://www.alphabet.com/robots.txt"
            case amazon = "https://www.amazon.com/robots.txt"
            case apple = "https://www.apple.com/robots.txt"
            case facebook = "https://www.facebook.com/robots.txt"
            case intel = "https://www.intel.com/robots.txt"
            case netflix = "https://www.netflix.com/robots.txt"

            var headerFields: [String: String] {

                switch self {
                case .alphabet:
                    return ["HeaderA": "ValueA"]
                case .amazon,
                     .apple,
                     .facebook,
                     .intel,
                     .netflix:
                    return [:]
                }
            }

            var profile: FNMProfile {

                let request = FNMProfileRequest(urlPattern: .staticPattern(url: self.rawValue))
                let responses: [FNMProfileResponse]

                switch self {
                case .alphabet:
                    responses = [request.response(identifier: "Identifier-Alphabet",
                                                  statusCode: 200,
                                                  headers: ["headerA" : "valueA"],
                                                  responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value:
                                                    [
                                                        "fieldA": "valueA",
                                                        "fieldB": "valueB",
                                                  ]),
                                                  repeatability: .unlimited,
                                                  delay: 0.25)]
                case .amazon:
                    responses = [request.response(identifier: "Identifier-Amazon",
                                                  statusCode: 202,
                                                  headers: ["headerA" : "valueA"],
                                                  responseHolder: FNMProfileRequest.ResponseHolder.json(filename: Constants.genericProfilesResponseFilename,
                                                                                                        bundle: Bundle.main),
                                                  repeatability: .limited(numberOfUsesTotal: 1),
                                                  delay: 0.15)]
                case .apple:

                    guard let filePath = NetworkMonitorUnitTests.testBundle.path(forResource: Constants.genericProfilesResponseFilename,
                                                                                 ofType: Constants.jsonFileExtension),
                        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { preconditionFailure("This file should be available") }

                    responses = [request.response(identifier: "Identifier-Apple",
                                                  statusCode: 200,
                                                  headers: ["headerA" : "valueA"],
                                                  responseHolder: FNMProfileRequest.ResponseHolder.raw(value: data),
                                                  repeatability: .limited(numberOfUsesTotal: 2),
                                                  delay: 1.0)]

                case .facebook:
                    responses = [request.response(identifier: "Identifier-Facebook",
                                                  statusCode: 202,
                                                  headers: ["headerA" : "valueA"],
                                                  responseHolder: FNMProfileRequest.ResponseHolder.values(values: ["1", "2", "3", "4", "5"].map {
                                                    [
                                                        "fieldA": $0,
                                                    ]
                                                  }),
                                                  repeatability: .unlimited,
                                                  delay: 0.15)]

                case .intel:
                    responses = [request.response(identifier: "Identifier-Intel",
                                                  statusCode: 200,
                                                  headers: ["headerA" : "valueA"],
                                                  responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value:
                                                    [
                                                        "fieldA": "valueA",
                                                        "fieldB": "valueB",
                                                  ]),
                                                  repeatability: .limited(numberOfUsesTotal: 4),
                                                  delay: 0.25)]

                case .netflix:

                    guard let filePath = NetworkMonitorUnitTests.testBundle.path(forResource: Constants.blackImageFilename,
                                                                                 ofType: Constants.pngFileExtension),
                        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { preconditionFailure("This file should be available") }

                    responses = [request.response(identifier: "Identifier-Netflix",
                                                  statusCode: 200,
                                                  headers: ["headerA" : "valueA"],
                                                  responseHolder: FNMProfileRequest.ResponseHolder.raw(value: data),
                                                  repeatability: .unlimited,
                                                  delay: 0.25)]
                }

                return FNMProfile(request: request,
                                  responses: responses)
            }
        }
    }
}

class NetworkMonitorFlowTests: NetworkMonitorUnitTests {

    func testLiveRequestRecordsConcurrently() {

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring()

        let robotsExpectation = expectation(description: "Some Robots")
        self.reachVariousSitesConcurrently(expectation: robotsExpectation)

        waitForExpectations(timeout: 60) { _ in

            XCTAssertEqual(self.networkMonitor.records.count, Constants.Sites.allCases.count)

            for site in Constants.Sites.allCases {

                let filteredRecord = self.networkMonitor.records.values.first(where: { record -> Bool in

                    if let conclusion = record.conclusion ,
                        case .completed(let loadState, _, _) = conclusion,
                        case .network(let task) = loadState,
                        task.originalRequest?.url?.absoluteString == site.rawValue {

                        return true
                    }

                    return false
                })

                if let conclusion = filteredRecord?.conclusion,
                    case .completed(let loadState, let response, _) = conclusion,
                    case .network(let task) = loadState {

                    XCTAssertEqual(task.originalRequest?.httpMethod, "GET")
                    XCTAssertEqual(task.originalRequest?.url?.absoluteString, site.rawValue)
                    XCTAssertEqual(task.response.debugDescription, response.debugDescription)

                } else {

                    XCTFail("Request to Robots failed")
                }
            }
        }
    }

    func testLiveRequestRecordsSequentially() {

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring()

        let robotsExpectation = expectation(description: "Some Robots")
        self.reachSitesSequencially(expectation: robotsExpectation)

        waitForExpectations(timeout: 60) { _ in

            XCTAssertEqual(self.networkMonitor.records.count, Constants.Sites.allCases.count)

            let records = self.networkMonitor.records.values.sorted(by: { $0.startTimestamp < $1.startTimestamp })

            for (index, record) in records.enumerated() {

                let site = Constants.Sites.allCases[index]

                if let conclusion = record.conclusion ,
                    case .completed(let loadState, let response, _) = conclusion,
                     case .network(let task) = loadState {

                    XCTAssertEqual(task.originalRequest?.httpMethod, "GET")
                    XCTAssertEqual(task.originalRequest?.url?.absoluteString, site.rawValue)
                    XCTAssertEqual(task.response.debugDescription, response.debugDescription)

                } else {

                    XCTFail("Request to Robots failed")
                }
            }
        }
    }

    func testRequestRecords() {

        self.networkMonitor.configure(profiles: Constants.Sites.allCases.map { $0.profile })
        self.networkMonitor.clear(completion: { } )
        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring()

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        let robotsExpectation = expectation(description: "Some Robots")
        self.reachSitesSequencially(expectation: robotsExpectation)

        waitForExpectations(timeout: 60) { _ in

            XCTAssertEqual(self.networkMonitor.records.count, Constants.Sites.allCases.count)

            let records = self.networkMonitor.records.values.sorted(by: { $0.startTimestamp < $1.startTimestamp })

            for (index, record) in records.enumerated() {

                let site = Constants.Sites.allCases[index]

                if let conclusion = record.conclusion ,
                    case .completed(let loadState, let HTTPResponse, let data) = conclusion,
                     case .profile(let profile, let profileResponse) = loadState {

                    let profileUsed = site.profile
                    let profileResponseUsed = profileUsed.responses.first

                    XCTAssertEqual(profile.request.urlPattern, profileUsed.request.urlPattern)
                    XCTAssertEqual(profile.request.httpMethod, profileUsed.request.httpMethod)
                    XCTAssertEqual(profile.request.body, profileUsed.request.body)
                    XCTAssertEqual(profile.request.headers, profileUsed.request.headers)

                    XCTAssertEqual(profileResponse.identifier, profileResponseUsed?.identifier)
                    XCTAssertEqual(profileResponse.response?.count, profileResponseUsed?.response?.count)
                    XCTAssertEqual(profileResponse.delay, profileResponseUsed?.delay)
                    XCTAssertEqual(profileResponse.repeatability, profileResponseUsed?.repeatability)
                    XCTAssertEqual(profileResponse.meta.meta.url, profileResponseUsed?.meta.meta.url)
                    XCTAssertEqual(profileResponse.meta.meta.statusCode, profileResponseUsed?.meta.meta.statusCode)

                    XCTAssertEqual(profile.request.httpMethod.rawValue, "GET")
                    XCTAssertNil(profile.request.headers)
                    XCTAssertNil(profile.request.body)

                    XCTAssertEqual(profileResponse.meta.meta.statusCode, HTTPResponse?.statusCode)

                    for (key, value) in profileResponse.meta.meta.allHeaderFields {

                        XCTAssertEqual(value as? String, HTTPResponse?.allHeaderFields[key] as? String)
                    }

                    XCTAssertEqual(data?.count, profileResponse.response?.count)

                } else {

                    XCTFail("Request to Robots failed")
                }
            }
        }
    }

    func testProfileResponseUsages() {

        self.networkMonitor.configure(profiles: Constants.Sites.allCases.map { $0.profile })
        self.networkMonitor.clear(completion: { } )
        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring()

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        XCTAssertEqual(self.networkMonitor.profilesUsageMap, [:])

        let robotsExpectation = expectation(description: "Some Robots")

        self.reachSitesSequencially {

            XCTAssertEqual(self.networkMonitor.records.count, 6)

            XCTAssertEqual(self.networkMonitor.profilesUsageMap, ["Identifier-Intel": 1,
                                                                  "Identifier-Netflix": 1,
                                                                  "Identifier-Amazon": 1,
                                                                  "Identifier-Alphabet": 1,
                                                                  "Identifier-Apple": 1,
                                                                  "Identifier-Facebook": 1])

            self.reachSitesSequencially {

                XCTAssertEqual(self.networkMonitor.records.count, 12)

                XCTAssertEqual(self.networkMonitor.profilesUsageMap, ["Identifier-Intel": 2,
                                                                      "Identifier-Netflix": 2,
                                                                      "Identifier-Amazon": 1,
                                                                      "Identifier-Alphabet": 2,
                                                                      "Identifier-Apple": 2,
                                                                      "Identifier-Facebook": 2])

                self.reachSitesSequencially {

                    XCTAssertEqual(self.networkMonitor.records.count, 18)

                    XCTAssertEqual(self.networkMonitor.profilesUsageMap, ["Identifier-Intel": 3,
                                                                          "Identifier-Netflix": 3,
                                                                          "Identifier-Amazon": 1,
                                                                          "Identifier-Alphabet": 3,
                                                                          "Identifier-Apple": 2,
                                                                          "Identifier-Facebook": 3])

                    self.reachSitesSequencially {

                        XCTAssertEqual(self.networkMonitor.records.count, 24)

                        XCTAssertEqual(self.networkMonitor.profilesUsageMap, ["Identifier-Intel": 4,
                                                                              "Identifier-Netflix": 4,
                                                                              "Identifier-Amazon": 1,
                                                                              "Identifier-Alphabet": 4,
                                                                              "Identifier-Apple": 2,
                                                                              "Identifier-Facebook": 4])

                        self.reachSitesSequencially {

                            XCTAssertEqual(self.networkMonitor.records.count, 30)

                            XCTAssertEqual(self.networkMonitor.profilesUsageMap, ["Identifier-Intel": 4,
                                                                                  "Identifier-Netflix": 5,
                                                                                  "Identifier-Amazon": 1,
                                                                                  "Identifier-Alphabet": 5,
                                                                                  "Identifier-Apple": 2,
                                                                                  "Identifier-Facebook": 5])

                            self.reachSitesSequencially {

                                XCTAssertEqual(self.networkMonitor.records.count, 36)

                                XCTAssertEqual(self.networkMonitor.profilesUsageMap, ["Identifier-Intel": 4,
                                                                                      "Identifier-Netflix": 6,
                                                                                      "Identifier-Amazon": 1,
                                                                                      "Identifier-Alphabet": 6,
                                                                                      "Identifier-Apple": 2,
                                                                                      "Identifier-Facebook": 6])

                                robotsExpectation.fulfill()
                            }
                        }
                    }
                }
            }
        }

        waitForExpectations(timeout: 100) { _ in }
    }

    func testURLProtocolInjectionPresent() {

        let config = URLSessionConfiguration.default

        XCTAssertFalse(config.protocolClasses![0].self == FNMNetworkMonitorURLProtocol.self)

        FNMNetworkMonitor.normalizeURLProtocolClasses(for: config)

        XCTAssertTrue(config.protocolClasses![0].self == FNMNetworkMonitorURLProtocol.self)
    }

    func testURLProtocolInjectionNotPresent() {

        let config = URLSessionConfiguration.default
        config.protocolClasses?.append(FNMNetworkMonitorURLProtocol.self)

        XCTAssertFalse(config.protocolClasses![0].self == FNMNetworkMonitorURLProtocol.self)
        XCTAssertTrue(config.protocolClasses![5].self == FNMNetworkMonitorURLProtocol.self)

        FNMNetworkMonitor.normalizeURLProtocolClasses(for: config)

        XCTAssertTrue(config.protocolClasses![0].self == FNMNetworkMonitorURLProtocol.self)
        XCTAssertFalse(config.protocolClasses![5].self == FNMNetworkMonitorURLProtocol.self)
    }

    func testProfileValidation() {

        let profiles: [FNMProfile] = FNMProfile.decodedElements(from: Self.testBundle,
                                                                filename: Constants.genericProfilesFilename)

        let profileResponsesDuplicated: [FNMProfile] = FNMProfile.decodedElements(from: Self.testBundle,
                                                                                  filename: Constants.genericProfilesDuplicatedFilename)

        let profileResponsesEmpty: [FNMProfile] = FNMProfile.decodedElements(from: Self.testBundle,
                                                                             filename: Constants.matchingProfiles1Filename)
        XCTAssertEqual(profiles.count, 3)
        XCTAssertEqual(profileResponsesDuplicated.count, 3)
        XCTAssertEqual(profileResponsesEmpty.count, 4)

        XCTAssertFalse(self.networkMonitor.validate(profiles: profileResponsesDuplicated))
        XCTAssertTrue(self.networkMonitor.validate(profiles: profiles))
        XCTAssertTrue(self.networkMonitor.validate(profiles: profileResponsesEmpty))
    }
}
