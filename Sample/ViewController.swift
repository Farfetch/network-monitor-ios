//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import UIKit
import FNMNetworkMonitor

final class ViewController: UIViewController {

    enum Constants {

        static let labelTopPadding: CGFloat = 60.0
        static let imageSidePadding: CGFloat = 15.0
        static let imageBorderWidth: CGFloat = 3.0

        static let robotURL = "https://www.alphabet.com/robots.txt"
        static let errorURL = "https://www.ohthehumanity.error"

        static let randomImageURL = "https://picsum.photos/500?random"
    }

    private enum TestRequest: CaseIterable {

        case imageRedirect
        case error
        case robot

        static var random: TestRequest {

            let index = Int(arc4random_uniform(UInt32(self.allCases.count)))
            return self.allCases[index]
        }
    }

    var imageView = UIImageView()
    var label = UILabel()
    var timer: Timer?

    var customSession: URLSession?

    override func viewDidLoad() {

        super.viewDidLoad()

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = FNMNetworkMonitor.normalizedURLProtocols()
        self.customSession = URLSession(configuration: sessionConfig)

        self.configureView()
        self.startMonitoring()

        self.timer = Timer.scheduledTimer(withTimeInterval: 3,
                                          repeats: true,
                                          block: { _ in self.fire() })

        FNMNetworkMonitor.shared.showDebugListingViewController(presentingNavigationController: self.navigationController)
    }

    func configureView() {

        let superviewGuide = self.view.safeAreaLayoutGuide

        self.label.text = "Sample App"
        self.imageView.contentMode = .scaleToFill
        self.imageView.clipsToBounds = true

        self.view.addSubview(self.label)
        self.view.addSubview(self.imageView)

        self.label.translatesAutoresizingMaskIntoConstraints = false
        self.label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        self.label.topAnchor.constraint(equalTo: superviewGuide.topAnchor,
                                        constant: Constants.labelTopPadding).isActive = true

        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.imageView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        self.imageView.leadingAnchor.constraint(equalTo: superviewGuide.leadingAnchor,
                                                constant: Constants.imageSidePadding).isActive = true
        self.imageView.trailingAnchor.constraint(equalTo: superviewGuide.trailingAnchor,
                                                 constant: -Constants.imageSidePadding).isActive = true
        self.imageView.widthAnchor.constraint(equalTo: self.imageView.heightAnchor, constant: 0).isActive = true
    }

    func startMonitoring() {

        let request = FNMProfileRequest(urlPattern: .staticPattern(url: Constants.robotURL))
        let profiles = [FNMProfile(request: request,
                                   responses: [request.response(statusCode: 200,
                                                                delay: 0.25)])]

        FNMNetworkMonitor.registerToLoadingSystem()
        FNMNetworkMonitor.shared.configure(profiles: profiles)

        FNMNetworkMonitor.shared.startMonitoring()
        FNMNetworkMonitor.shared.passiveExportPreference = .on(setting: .unlimited)
        FNMNetworkMonitor.shared.logScope = [.export, .profile, .urlProtocol]
    }

    func fire() {

        let random = TestRequest.random

        print("Fired \(random)")

        switch random {

        case .imageRedirect:

            URLSession.shared.dataTask(with: URL(string: Constants.randomImageURL)!) { data, _, _ in

                guard let data = data,
                    let image = UIImage(data: data)
                    else { return }

                self.applyImage(image: image)
            }.resume()

        case .error:
            self.customSession?.dataTask(with: URL(string: Constants.errorURL)!).resume()

        case .robot:
            URLSession.shared.dataTask(with: URL(string: Constants.robotURL)!).resume()
        }
    }

    func applyImage(image: UIImage) {

        DispatchQueue.main.async {

            self.imageView.image = image
            self.imageView.layer.borderColor = UIColor.blue.cgColor
            self.imageView.layer.borderWidth = Constants.imageBorderWidth
        }
    }
}
