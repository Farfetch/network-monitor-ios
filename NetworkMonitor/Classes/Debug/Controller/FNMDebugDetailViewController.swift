//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation
import MessageUI

final class FNMDebugDetailViewController: FNMViewController {

    // MARK: Properties

    private let record: FNMHTTPRequestRecord
    private let recordDetailInfo: FNMRecordDetailInfo

    private let searchBar = UISearchBar()
    private let pageController = UIPageViewController(transitionStyle: .scroll,
                                                      navigationOrientation: .horizontal)

    let headersViewController: DebugDetailHeadersViewController & HighlightReloadable
    let requestBodyViewController: DebugDetailBodyViewController & HighlightReloadable
    let responseBodyViewController: DebugDetailBodyViewController & HighlightReloadable

    // MARK: Lifecycle

    init(record: FNMHTTPRequestRecord) {

        self.record = record
        self.recordDetailInfo = FNMRecordDetailInfo(record: record)

        let headerDetails = self.recordDetailInfo.headersDetails
        self.headersViewController = DebugDetailHeadersViewController(recordHeaderDetailInfo: headerDetails)

        let requestBodyDetails = self.recordDetailInfo.requestBodyDetails
        self.requestBodyViewController = DebugDetailBodyViewController(recordBodyDetailInfo: requestBodyDetails)

        let responseBodyDetails = self.recordDetailInfo.responseBodyDetails
        self.responseBodyViewController = DebugDetailBodyViewController(recordBodyDetailInfo: responseBodyDetails)

        super.init(nibName: nil,
                   bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {

        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {

        super.viewDidLoad()

        self.configureViews()
    }

    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)

        self.configureNavigationBar()
    }
}

// MARK: - Layout

private extension FNMDebugDetailViewController {

    // MARK: - Constants

    enum Constants {

        static let title = "Network"
        static let searchPlaceholderTitle = "Highlight keyword"
        static let exportTitle = "Export"
        static let copyTitle = "Copy"
        static let exportMime = "application/json"
        static let exportFilename = "request-original.json"
        static let alertTitle = "This device can't send emails 🤷"
        static let alertDismiss = "Dismiss"

        static let searchBarHeight: CGFloat = 60.0

        static let backImage = "chevron.left"
        static let exportImage = "square.and.arrow.up"
        static let copyImage = "doc.on.doc"
    }

    // MARK: - Layout Configuration

    func configureNavigationBar() {

        self.navigationItem.title = Constants.title

        if #available(iOS 13.0, *) {

            self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: Constants.backImage),
                                                                     style: .plain,
                                                                     target: self,
                                                                     action: #selector(self.back))

            let copyButton = UIBarButtonItem(image: UIImage(systemName: Constants.copyImage),
                                             style: .plain,
                                             target: self,
                                             action: #selector(self.copyResponseContents))

            let exportButton = UIBarButtonItem(image: UIImage(systemName: Constants.exportImage),
                                               style: .plain,
                                               target: self,
                                               action: #selector(self.exportViaEmail))

            self.navigationItem.rightBarButtonItems = [exportButton, copyButton]

        } else {

            let copyButton = UIBarButtonItem(title: Constants.copyTitle,
                                             style: .plain,
                                             target: self,
                                             action: #selector(self.exportViaEmail))

            let exportButton = UIBarButtonItem(title: Constants.exportTitle,
                                             style: .plain,
                                             target: self,
                                             action: #selector(self.exportViaEmail))

            self.navigationItem.rightBarButtonItems = [exportButton, copyButton]
        }
    }

    func configureViews() {

        self.searchBar.delegate = self
        self.searchBar.placeholder = Constants.searchPlaceholderTitle
        self.searchBar.barTintColor = .white

        self.forceSearchBarTextColor(self.searchBar)

        self.pageController.dataSource = self

        self.view.addSubview(self.searchBar)
        self.view.addSubview(self.pageController.view)

        let superviewGuide: UILayoutGuide

        if #available(iOS 11.0, *) {

            superviewGuide = self.view.safeAreaLayoutGuide

        } else {

            superviewGuide = self.view.readableContentGuide
        }

        self.searchBar.translatesAutoresizingMaskIntoConstraints = false
        self.searchBar.topAnchor.constraint(equalTo: superviewGuide.topAnchor).isActive = true
        self.searchBar.leadingAnchor.constraint(equalTo: superviewGuide.leadingAnchor).isActive = true
        self.searchBar.trailingAnchor.constraint(equalTo: superviewGuide.trailingAnchor).isActive = true

        self.pageController.view.translatesAutoresizingMaskIntoConstraints = false
        self.pageController.view.topAnchor.constraint(equalTo: self.searchBar.bottomAnchor).isActive = true
        self.pageController.view.bottomAnchor.constraint(equalTo: superviewGuide.bottomAnchor).isActive = true
        self.pageController.view.leadingAnchor.constraint(equalTo: superviewGuide.leadingAnchor).isActive = true
        self.pageController.view.trailingAnchor.constraint(equalTo: superviewGuide.trailingAnchor).isActive = true

        self.pageController.setViewControllers([self.headersViewController],
                                               direction: .forward,
                                               animated: false)
    }

    func currentSearchFilter() -> String? {

        return self.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) != "" ? self.searchBar.text : nil
    }
}

// MARK: - Private

private extension FNMDebugDetailViewController {

    @objc
    func exportViaEmail() {

        if MFMailComposeViewController.canSendMail() {

            if let encodedRecordsData = self.encodedRecordData {

                let date = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy HH:mm:ss.SSS"

                let displayDate = formatter.string(from: date)
                let displayName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""

                let mail = MFMailComposeViewController()
                mail.mailComposeDelegate = self
                mail.setSubject("Monitor Request Exported at \(displayDate) for '\(displayName)'")
                mail.addAttachmentData(encodedRecordsData,
                                       mimeType: Constants.exportMime,
                                       fileName: Constants.exportFilename)

                present(mail, animated: true)

            } else {

                assertionFailure("Failed to encode, please advise")
            }

        } else {

            let alertViewController = UIAlertController(title: Constants.alertTitle,
                                                        message: nil,
                                                        preferredStyle: .alert)
            alertViewController.addAction(UIAlertAction(title: Constants.alertDismiss,
                                                        style: .cancel))

            self.navigationController?.present(alertViewController, animated: true)
        }
    }

    @objc
    func copyResponseContents() {

        UIPasteboard.general.string = self.encodedRecordString ?? "Invalid copy contents"
    }

    @objc
    func back() {

        self.navigationController?.popViewController(animated: true)
    }

    private var encodedRecordData: Data? {

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // Inefficient but the file size difference isn't significant

        return try? encoder.encode(self.recordDetailInfo)
    }

    private var encodedRecordString: String? {

        if let encodedData = self.encodedRecordData {

            return String(data: encodedData, encoding: .utf8)

        } else {

            return nil
        }
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension FNMDebugDetailViewController: MFMailComposeViewControllerDelegate {

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {

        controller.dismiss(animated: true)
    }
}

// MARK: - UIPageViewControllerDataSource

extension FNMDebugDetailViewController: UIPageViewControllerDataSource {

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {

        if viewController == self.headersViewController {

            return self.requestBodyViewController

        } else if viewController == self.responseBodyViewController {

            return self.headersViewController
        }

        return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {

        if viewController == self.requestBodyViewController {

            return self.headersViewController

        } else if viewController == self.headersViewController {

            return self.responseBodyViewController
        }

        return nil
    }
}

// MARK: - UISearchBarDelegate

extension FNMDebugDetailViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {

        self.headersViewController.reloadData(with: self.currentSearchFilter())
        self.requestBodyViewController.reloadData(with: self.currentSearchFilter())
        self.responseBodyViewController.reloadData(with: self.currentSearchFilter())
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {

        searchBar.resignFirstResponder()
    }
}

// MARK: - Private FNMRecordDetailInfo utilities

private extension FNMRecordDetailInfo {

    var headersDetails: RecordHeaderDetailInfo {

        RecordHeaderDetailInfo(record: self.record,
                               requestHeaders: self.requestHeaders,
                               responseHeaders: self.responseHeaders)
    }

    var requestBodyDetails: RecordBodyDetailInfo {

        RecordBodyDetailInfo(record: self.record, body: self.requestBody)
    }

    var responseBodyDetails: RecordBodyDetailInfo {

        RecordBodyDetailInfo(record: self.record, body: self.responseBody)
    }
}
