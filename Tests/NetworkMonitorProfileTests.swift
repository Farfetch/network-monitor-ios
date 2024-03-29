//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import XCTest
@testable import FNMNetworkMonitor

class NetworkMonitorProfileTests: NetworkMonitorUnitTests {

    enum URLConstants {

        static let repeatTastySecretiveYarnMuddledGET = "https://repeat.tasty.secretive.yarn/muddled/get"
        static let repeatTastySecretiveYarnMuddledPOST = "https://repeat.tasty.secretive.yarn/muddled/post"
        static let repeatTastySecretiveYarnMuddledHEAD = "https://repeat.tasty.secretive.yarn/muddled/head"
        static let repeatTastySecretiveYarnMuddledCore = "repeat.tasty.secretive.yarn"
        static let balanceAbandonedGruesomeBreatheUseGET = "https://balance.abandoned.gruesome.breathe/use/get"
        static let balanceAbandonedGruesomeBreatheUsePOST = "https://balance.abandoned.gruesome.breathe/use/post"

        static let dynamicBalanceAbandonedGruesomeBreatheUseGET = "^.*gruesome.breathe/use/get"
        static let dynamicBalanceAbandonedGruesomeBreatheUsePOST = "^.*gruesome.breathe/use/post"

        static let httpsWildcard = "https://*"

        static let GET = "GET"
        static let POST = "POST"
        static let HEAD = "HEAD"

        static let headerKeyNaco = "Naco"
        static let headerValuePimenta = "Pimenta"

        static let headerKeyCountry = "FF-Country"
        static let headerValueUS = "US"

        static let headerKeyCurrency = "FF-Currency"
        static let headerValueUSD = "USD"

        static let bodyEmpty = ""
        static let bodySwimsuit = "Swimsuit"
        static let bodySwimsuitBody = "Swimsuit body"
        static let bodySwimsuitBodyLowered = "swimsuit body"
        static let bodySwimsuitBodyLong = " swimsuit body Swimsuit body "
    }

    override func setUp() {

        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.startMonitoring()
        FNMNetworkMonitor.shared.passiveExportPreference = .off

        super.setUp()
    }

    func testProfilesCompletionStatic() {

        let profileRequest = FNMProfileRequest(urlPattern: .staticPattern(url: URLConstants.repeatTastySecretiveYarnMuddledGET))
        let responses = [profileRequest.response(headers: ["Content-Type": "application/json"],
                                                 responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value: [
                                                    "FieldA": 1,
                                                    "FieldB": 5
                                                 ]))]

        FNMNetworkMonitor.shared.configure(profiles: [FNMProfile(request: profileRequest, responses: responses)])

        let request = self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                   httpMethod: "GET")

        let profileExpectation = expectation(description: "Some Robots")

        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in

            do {

                let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data),
                                                                      options: []) as? [String: Any])

                XCTAssertEqual(dict.values.count, 2)
                XCTAssertEqual(dict["FieldA"] as! Int, 1)
                XCTAssertEqual(dict["FieldB"] as! Int, 5)
            }
            catch {

                XCTFail()
            }

            profileExpectation.fulfill()

        }.resume()

        waitForExpectations(timeout: 60) { _ in

        }
    }

    func testProfilesCompletionDynamic() {

        let profileRequest = FNMProfileRequest(urlPattern: .dynamicPattern(expression: URLConstants.repeatTastySecretiveYarnMuddledCore))
        let responses = [profileRequest.response(headers: ["Content-Type": "application/json"],
                                                 responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value: [
                                                    "FieldA": 1,
                                                    "FieldB": 5
                                                 ]))]

        FNMNetworkMonitor.shared.configure(profiles: [FNMProfile(request: profileRequest, responses: responses)])

        let request = self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                   httpMethod: "GET")

        let profileExpectation = expectation(description: "Some Robots")

        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in

            do {

                let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data),
                                                                      options: []) as? [String: Any])

                XCTAssertEqual(dict.values.count, 2)
                XCTAssertEqual(dict["FieldA"] as! Int, 1)
                XCTAssertEqual(dict["FieldB"] as! Int, 5)
            }
            catch {

                XCTFail()
            }

            profileExpectation.fulfill()

        }.resume()

        waitForExpectations(timeout: 60) { _ in

        }
    }

    func testProfilesRedirection() {

        let profileRequestA = FNMProfileRequest(urlPattern: .staticPattern(url: URLConstants.repeatTastySecretiveYarnMuddledGET))
        let responsesA = [profileRequestA.response(headers: ["Content-Type": "application/json"],
                                                   redirectionURL: URL(string: URLConstants.balanceAbandonedGruesomeBreatheUseGET))]

        let profileRequestB = FNMProfileRequest(urlPattern: .staticPattern(url: URLConstants.balanceAbandonedGruesomeBreatheUseGET))
        let responsesB = [profileRequestB.response(headers: ["Content-Type": "application/json"],
                                                   responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value: [
                                                        "FieldA": 1
                                                   ]))]

        FNMNetworkMonitor.shared.configure(profiles: [FNMProfile(request: profileRequestA, responses: responsesA),
                                                      FNMProfile(request: profileRequestB, responses: responsesB)])

        let requestA = self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                    httpMethod: "GET")

        let profileExpectationA = expectation(description: "Some Robots")

        URLSession.shared.dataTask(with: requestA as URLRequest) { data, response, error in

            do {

                let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data),
                                                                      options: []) as? [String: Any])

                XCTAssertEqual(dict.values.count, 1)
                XCTAssertEqual(dict["FieldA"] as! Int, 1)
            }
            catch {

                XCTFail()
            }

            profileExpectationA.fulfill()

        }.resume()

        waitForExpectations(timeout: 60) { _ in

            print("Done")
        }
    }

    func testProfileMatchingURLAndMethods() {

        let profiles: [FNMProfile] = FNMProfile.decodedElements(from: Self.testBundle,
                                                                filename: Constants.matchingProfiles1Filename)

        XCTAssertEqual(profiles.count, 5)

        self.networkMonitor.configure(profiles: profiles)

        self.networkMonitor.clear(completion: { } )

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        /// Right URL, Static, Wrong method
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                           httpMethod: "")))

        /// Right URL, Static, Right method, GET
        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                             httpMethod: URLConstants.GET))!.request.urlPattern,
                       FNMRequestURLPattern.staticPattern(url: URLConstants.repeatTastySecretiveYarnMuddledGET))

        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                             httpMethod: URLConstants.GET))!.request.httpMethod,
                                       .get)

        /// Wrong URL, Static, Right method, POST
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.POST)))

        /// Right URL, Static, Right method, POST
        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledPOST,
                                                                              httpMethod: URLConstants.POST))!.request.urlPattern,
                       FNMRequestURLPattern.staticPattern(url: URLConstants.repeatTastySecretiveYarnMuddledPOST))

        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledPOST,
                                                                              httpMethod: URLConstants.POST))!.request.httpMethod,
                       .post)

        /// Right URL, Dynamic, Wrong method
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.balanceAbandonedGruesomeBreatheUseGET,
                                                                            httpMethod: "")))

        /// Right URL, Dynamic, Right method, GET
        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.balanceAbandonedGruesomeBreatheUseGET,
                                                                              httpMethod: URLConstants.GET))!.request.urlPattern,
                       FNMRequestURLPattern.dynamicPattern(expression: URLConstants.dynamicBalanceAbandonedGruesomeBreatheUseGET))

        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.balanceAbandonedGruesomeBreatheUseGET,
                                                                              httpMethod: URLConstants.GET))!.request.httpMethod,
                       .get)

        /// Wrong URL, Dynamic, Right method, POST
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.balanceAbandonedGruesomeBreatheUseGET,
                                                                            httpMethod: URLConstants.POST)))

        /// Right URL, Dynamic, Right method, POST
        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.balanceAbandonedGruesomeBreatheUsePOST,
                                                                              httpMethod: URLConstants.POST))!.request.urlPattern,
                       FNMRequestURLPattern.dynamicPattern(expression: URLConstants.dynamicBalanceAbandonedGruesomeBreatheUsePOST))

        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.balanceAbandonedGruesomeBreatheUsePOST,
                                                                              httpMethod: URLConstants.POST))!.request.httpMethod,
                       .post)
        
        /// Right URL, Static, Right method, HEAD
        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledHEAD,
                                                             httpMethod: URLConstants.HEAD))!.request.urlPattern,
                       FNMRequestURLPattern.staticPattern(url: URLConstants.repeatTastySecretiveYarnMuddledHEAD))
        
        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledHEAD,
                                                             httpMethod: URLConstants.HEAD))!.request.httpMethod,
                       .head)
    }

    func testProfileMatchingHeaders() {

        let profiles: [FNMProfile] = FNMProfile.decodedElements(from: Self.testBundle,
                                                                filename: Constants.matchingProfiles2Filename)
        XCTAssertEqual(profiles.count, 1)

        self.networkMonitor.configure(profiles: profiles)

        self.networkMonitor.clear(completion: { } )

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        /// Empty Headers
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.GET)))

        /// Wrong Headers
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.GET,
                                                                            httpHeaders: [URLConstants.headerKeyNaco : URLConstants.headerValuePimenta])))

        /// Incomplete Header Keys, Wrong Values
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.GET,
                                                                            httpHeaders: [URLConstants.headerKeyCountry : URLConstants.headerValuePimenta])))

        /// Incomplete Header Keys, Right Values
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.GET,
                                                                            httpHeaders: [URLConstants.headerKeyCountry : URLConstants.headerValueUS])))

        /// Incomplete and Wrong Header Keys
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.GET,
                                                                            httpHeaders: [URLConstants.headerKeyCountry : URLConstants.headerValueUS,
                                                                                          URLConstants.headerKeyNaco : URLConstants.headerValuePimenta])))

        /// Right Header Keys, Wrong Values
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.GET,
                                                                            httpHeaders: [URLConstants.headerKeyCountry : URLConstants.headerValueUS,
                                                                                          URLConstants.headerKeyCurrency : URLConstants.headerValuePimenta])))

        /// Right Header Keys, Right Values
        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                              httpMethod: URLConstants.GET,
                                                                              httpHeaders: [URLConstants.headerKeyCountry : URLConstants.headerValueUS,
                                                                                            URLConstants.headerKeyCurrency : URLConstants.headerValueUSD]))!.request.headers,
                       [URLConstants.headerKeyCountry : URLConstants.headerValueUS,
                        URLConstants.headerKeyCurrency : URLConstants.headerValueUSD])

        /// Right Header Keys, Right Values
        XCTAssertEqual(self.firstMatch(profiles: profiles,
                                       request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                              httpMethod: URLConstants.GET,
                                                                              httpHeaders: [URLConstants.headerKeyCountry : URLConstants.headerValueUS,
                                                                                            URLConstants.headerKeyCurrency : URLConstants.headerValueUSD,
                                                                                            URLConstants.headerKeyNaco : URLConstants.headerValuePimenta]))!.request.headers,
                       [URLConstants.headerKeyCountry : URLConstants.headerValueUS,
                        URLConstants.headerKeyCurrency : URLConstants.headerValueUSD])

        /// Right Header Keys, Right Values
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.POST,
                                                                            httpHeaders: [URLConstants.headerKeyCountry : URLConstants.headerValueUS,
                                                                                          URLConstants.headerKeyCurrency : URLConstants.headerValueUSD])))
    }

    func testProfileMatchingBodies() {

        let profiles: [FNMProfile] = FNMProfile.decodedElements(from: Self.testBundle,
                                                                filename: Constants.matchingProfiles3Filename)
        XCTAssertEqual(profiles.count, 1)

        self.networkMonitor.configure(profiles: profiles)

        self.networkMonitor.clear(completion: { } )

        XCTAssertNotNil(FNMNetworkMonitor.shared)
        XCTAssertEqual(self.networkMonitor.records.count, 0)

        /// Empty Body
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.GET)))

        /// Mismatched Body
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.GET,
                                                                            body: URLConstants.bodyEmpty)))

        /// Mismatched Body
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.GET,
                                                                            body: URLConstants.bodySwimsuit)))

        /// Mismatched Headers
        XCTAssertNil(self.firstMatch(profiles: profiles,
                                     request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                            httpMethod: URLConstants.GET,
                                                                            body: URLConstants.bodySwimsuitBodyLowered)))


        /// Equal Body
        XCTAssertEqual(String(data: self.firstMatch(profiles: profiles,
                                                    request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                          httpMethod: URLConstants.GET,
                                                                          body: URLConstants.bodySwimsuitBody))!.request.body!,
                              encoding: .utf8),
                       URLConstants.bodySwimsuitBody)


        /// Contained Body
        XCTAssertEqual(String(data: self.firstMatch(profiles: profiles,
                                                    request: self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                                                          httpMethod: URLConstants.GET,
                                                                          body: URLConstants.bodySwimsuitBodyLong))!.request.body!,
                              encoding: .utf8),
                       URLConstants.bodySwimsuitBody)
    }

    func testProfilesWithSamePriority() {

        let profileRequest = FNMProfileRequest(urlPattern: .staticPattern(url: URLConstants.repeatTastySecretiveYarnMuddledGET))
        let responses = [profileRequest.response(headers: ["Content-Type": "application/json"],
                                                 responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value: [
                                                    "FieldA": 1,
                                                    "FieldB": 2
                                                 ]))]

        let profileGet = FNMProfile(request: profileRequest,
                                    responses: responses,
                                    priority: 1)

        let profileRequestCore = FNMProfileRequest(urlPattern: .dynamicPattern(expression: URLConstants.repeatTastySecretiveYarnMuddledCore))
        let responsesCore = [profileRequestCore.response(headers: ["Content-Type": "application/json"],
                                                         responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value: [
                                                            "FieldA": 3,
                                                            "FieldB": 4
                                                         ]))]

        let profileCore = FNMProfile(request: profileRequestCore,
                                     responses: responsesCore,
                                     priority: 1)

        FNMNetworkMonitor.shared.configure(profiles: [profileGet, profileCore])

        let request = self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                   httpMethod: "GET")

        let profileExpectation = expectation(description: "Some Robots")

        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in

            do {

                let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data),
                                                                      options: []) as? [String: Any])

                // Values are expected to match those of the first profile in the array
                XCTAssertEqual(dict.values.count, 2)
                XCTAssertEqual(dict["FieldA"] as! Int, 1)
                XCTAssertEqual(dict["FieldB"] as! Int, 2)
            }
            catch {

                XCTFail()
            }

            profileExpectation.fulfill()

        }.resume()

        waitForExpectations(timeout: 60) { _ in

        }
    }

    func testProfilesWithDifferentPriorities() {

        let profileRequest = FNMProfileRequest(urlPattern: .staticPattern(url: URLConstants.repeatTastySecretiveYarnMuddledGET))
        let responses = [profileRequest.response(headers: ["Content-Type": "application/json"],
                                                 responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value: [
                                                    "FieldA": 1,
                                                    "FieldB": 2
                                                 ]))]

        let profileGet = FNMProfile(request: profileRequest,
                                    responses: responses,
                                    priority: 2)

        let profileRequestCore = FNMProfileRequest(urlPattern: .dynamicPattern(expression: URLConstants.repeatTastySecretiveYarnMuddledCore))
        let responsesCore = [profileRequestCore.response(headers: ["Content-Type": "application/json"],
                                                         responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value: [
                                                            "FieldA": 3,
                                                            "FieldB": 4
                                                         ]))]

        let profileCore = FNMProfile(request: profileRequestCore,
                                     responses: responsesCore,
                                     priority: 1)

        FNMNetworkMonitor.shared.configure(profiles: [profileGet, profileCore])

        let request = self.request(for: URLConstants.repeatTastySecretiveYarnMuddledGET,
                                   httpMethod: "GET")

        let profileExpectation = expectation(description: "Some Robots")

        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in

            do {

                let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data),
                                                                      options: []) as? [String: Any])

                // Values are expected to match those of the profile with highest priority(1) in the array
                XCTAssertEqual(dict.values.count, 2)
                XCTAssertEqual(dict["FieldA"] as! Int, 3)
                XCTAssertEqual(dict["FieldB"] as! Int, 4)
            }
            catch {

                XCTFail()
            }

            profileExpectation.fulfill()

        }.resume()

        waitForExpectations(timeout: 60) { _ in

        }
    }

    func testProfileWildcard() {

        let profileRequestTasty = FNMProfileRequest(urlPattern: .staticPattern(url: URLConstants.repeatTastySecretiveYarnMuddledGET))
        let responsesTasty = [profileRequestTasty.response(headers: ["Content-Type": "application/json"],
                                                           responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value: [
                                                            "FieldA": 1,
                                                            "FieldB": 2
                                                           ]))]

        let profileTasty = FNMProfile(request: profileRequestTasty,
                                      responses: responsesTasty,
                                      priority: 1)

        let profileRequestWildcard = FNMProfileRequest(urlPattern: .dynamicPattern(expression: URLConstants.httpsWildcard))
        let responsesWildcard = [profileRequestWildcard.response(headers: ["Content-Type": "application/json"],
                                                                 responseHolder: FNMProfileRequest.ResponseHolder.keyValue(value: [
                                                                    "FieldA": 3,
                                                                    "FieldB": 4
                                                                 ]))]

        let profileWildcard = FNMProfile(request: profileRequestWildcard,
                                         responses: responsesWildcard,
                                         priority: 2)

        FNMNetworkMonitor.shared.configure(profiles: [profileTasty, profileWildcard])

        let request = self.request(for: URLConstants.balanceAbandonedGruesomeBreatheUseGET,
                                   httpMethod: "GET")

        let profileExpectation = expectation(description: "Some Robots")

        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in

            do {

                let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data),
                                                                      options: []) as? [String: Any])

                // Values are expected to match those of the wildcard profile in the array
                XCTAssertEqual(dict.values.count, 2)
                XCTAssertEqual(dict["FieldA"] as! Int, 3)
                XCTAssertEqual(dict["FieldB"] as! Int, 4)
            }
            catch {

                XCTFail()
            }

            profileExpectation.fulfill()

        }.resume()

        waitForExpectations(timeout: 60) { _ in

        }
    }
}
