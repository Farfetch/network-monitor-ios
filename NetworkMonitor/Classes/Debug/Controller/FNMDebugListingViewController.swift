//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import UIKit
import MessageUI

final class FNMDebugListingViewController: FNMViewController {

    // MARK: Properties

    var allRecords = [FNMHTTPRequestRecord]() {

        didSet {

            self.updateFilteredValues()
        }
    }
    private var filteredRecords = [FNMHTTPRequestRecord]() {

        didSet {

            self.reloadTableView()
        }
    }

    let tableView = UITableView(frame: .zero,
                                style: .plain)
    private let searchBar = UISearchBar()

    private var sortOrder: SortOrder {
        get {
            return SortOrder(rawValue: type(of: self).defaults().integer(forKey: SortOrder.key) as Int) ?? .oldestFirst
        }
        set(newSortOrder) {
            type(of: self).defaults().set(newSortOrder.rawValue, forKey: SortOrder.key)
        }
    }
    private var errorFilterType: ErrorFilterType = .allRequests

    // MARK: Lifecycle

    override func viewDidLoad() {

        super.viewDidLoad()

        self.configureViews()

        self.observeMonitor()
    }

    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)

        self.configureNavigationBar()
    }

    deinit {

        FNMNetworkMonitor.shared.unsubscribe(observer: self)
    }
}

// MARK: - Layout

private extension FNMDebugListingViewController {

    enum SortOrder: Int {

        static let key = "UserDefaultsSortOrderKey"

        case oldestFirst = 0
        case newestFirst = 1
    }

    enum ErrorFilterType: Int {

        case allRequests = 0
        case errorsOnly = 1
    }

    // MARK: - Constants

    enum Constants {

        static let title = "Network"
        static let toggleSortTitle = "Sort"
        static let toggleErrorTitle = "Errors Only"
        static let toggleResetTitle = "Reset"
        static let searchPlaceholderTitle = "Filter here"
        static let exportTitle = "Export"
        static let exportMime = "application/json"
        static let exportSlimFilename = "all-requests-slim-original.json"
        static let exportDetailedFilename = "all-requests-detailed-original.json"
        static let alertResetTitle = "Are you sure you want to reset ?"
        static let alertCancel = "Cancel"
        static let alertReset = "Reset 💪"
        static let alertExportTitle = "This device can't send emails 🤷"
        static let alertDismiss = "Dismiss"
        static let searchBarPlaceholder = "Filter by endpoint"

        static let tableViewEstimatedHeight: CGFloat = 80.0
        static let reloadTableViewAnimationDuration: Double = 0.1
        static let reloadTableViewAnimationKey = "reloadTableViewAnimationKey"

        static let backImage = "chevron.left"
        static let exportImage = "square.and.arrow.up"
        static let sortImage = "arrow.up.arrow.down"
        static let errorImage = "exclamationmark.triangle.fill"
        static let resetImage = "trash"
    }

    func configureViews() {

        self.configureTableView()
    }

    func configureNavigationBar() {

        self.navigationItem.title = Constants.title

        if #available(iOS 13.0, *) {

            self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: Constants.backImage),
                                                                    style: .plain,
                                                                    target: self,
                                                                    action: #selector(self.back))

            self.navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: Constants.exportImage),
                                                                       style: .plain,
                                                                       target: self,
                                                                       action: #selector(self.exportViaEmail)),
                                                       UIBarButtonItem(image: UIImage(systemName: Constants.sortImage),
                                                                       style: .plain,
                                                                       target: self,
                                                                       action: #selector(self.toggleSortOrder)),
                                                       UIBarButtonItem(image: UIImage(systemName: Constants.errorImage),
                                                                       style: .plain,
                                                                       target: self,
                                                                       action: #selector(self.toggleErrorMode)),
                                                       UIBarButtonItem(image: UIImage(systemName: Constants.resetImage),
                                                                       style: .plain,
                                                                       target: self,
                                                                       action: #selector(self.resetRecords))]

        } else {

            self.navigationItem.rightBarButtonItems = [UIBarButtonItem(title: Constants.exportTitle,
                                                                       style: .plain,
                                                                       target: self,
                                                                       action: #selector(self.exportViaEmail)),
                                                       UIBarButtonItem(title: Constants.toggleSortTitle,
                                                                       style: .plain,
                                                                       target: self,
                                                                       action: #selector(self.toggleSortOrder)),
                                                       UIBarButtonItem(title: Constants.toggleErrorTitle,
                                                                       style: .plain,
                                                                       target: self,
                                                                       action: #selector(self.toggleErrorMode)),
                                                       UIBarButtonItem(title: Constants.toggleResetTitle,
                                                                       style: .plain,
                                                                       target: self,
                                                                       action: #selector(self.resetRecords))]
        }
    }

    func configureTableView() {

        self.searchBar.delegate = self
        self.searchBar.placeholder = Constants.searchPlaceholderTitle
        self.searchBar.barTintColor = .white

        self.forceSearchBarTextColor(self.searchBar)

        self.tableView.register(FNMDebugSummaryTableViewCell.self,
                                forCellReuseIdentifier: FNMDebugSummaryTableViewCell.reuseIdentifier())
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = Constants.tableViewEstimatedHeight
        self.tableView.separatorInset = UIEdgeInsets.zero
        self.tableView.keyboardDismissMode = .onDrag
        self.tableView.backgroundColor = .white

        self.view.addSubview(self.searchBar)
        self.view.addSubview(self.tableView)

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

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.topAnchor.constraint(equalTo: self.searchBar.bottomAnchor).isActive = true
        self.tableView.bottomAnchor.constraint(equalTo: superviewGuide.bottomAnchor).isActive = true
        self.tableView.leadingAnchor.constraint(equalTo: superviewGuide.leadingAnchor).isActive = true
        self.tableView.trailingAnchor.constraint(equalTo: superviewGuide.trailingAnchor).isActive = true
    }
}

// MARK: - Private

private extension FNMDebugListingViewController {

    func reloadTableView() {

        let transition = CATransition()
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        transition.fillMode = CAMediaTimingFillMode.removed
        transition.duration = Constants.reloadTableViewAnimationDuration
        transition.type = CATransitionType.fade

        self.tableView.layer.add(transition,
                                 forKey: Constants.reloadTableViewAnimationKey)
        self.tableView.reloadData()
    }

    func observeMonitor() {

        // Observe the Monitor
        self.updateAllRecords(to: Array(FNMNetworkMonitor.shared.records.values))

        FNMNetworkMonitor.shared.subscribe(observer: self)
    }

    func currentSearchFilter() -> String? {

        return self.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) != "" ? self.searchBar.text : nil
    }

    func updateAllRecords(to newAllRecords: [FNMHTTPRequestRecord]) {

        self.allRecords = newAllRecords.sorted { $0.startTimestamp.timeIntervalSince1970 < $1.startTimestamp.timeIntervalSince1970 }

        self.updateFilteredValues()
    }

    func updateFilteredValues() {

        typealias RecordFilter = (FNMHTTPRequestRecord) -> Bool

        let searchFilter: RecordFilter = {
            guard let currentSearchFilter = self.currentSearchFilter() else { return true }
            return $0.request.url?.absoluteString.lowercased().contains(currentSearchFilter.lowercased()) == true
        }

        let errorFilter: RecordFilter = {
            guard self.errorFilterType == .errorsOnly else { return true }

            guard let conclusion = $0.conclusion else { return false }

            if case FNMHTTPRequestRecordConclusionType.completed(_, let response, _) = conclusion {

                return response?.isSuccessful() == false

            } else if case FNMHTTPRequestRecordConclusionType.clientError(_) = conclusion {

                return true
            }

            return false
        }

        let filteredRecords = self.allRecords.filter { return searchFilter($0) && errorFilter($0) }

        self.filteredRecords = filteredRecords.sorted {

            switch self.sortOrder {
            case .newestFirst:
                return $1.startTimestamp.timeIntervalSince1970 < $0.startTimestamp.timeIntervalSince1970
            case .oldestFirst:
                return $0.startTimestamp.timeIntervalSince1970 < $1.startTimestamp.timeIntervalSince1970
            }
        }
    }

    @objc
    func toggleSortOrder() {

        switch self.sortOrder {
        case .oldestFirst:
            self.sortOrder = .newestFirst
        case .newestFirst:
            self.sortOrder = .oldestFirst
        }

        self.updateFilteredValues()
    }

    @objc
    func toggleErrorMode() {

        switch self.errorFilterType {
        case .allRequests:
            self.errorFilterType = .errorsOnly
        case .errorsOnly:
            self.errorFilterType = .allRequests
        }

        self.updateFilteredValues()
    }

    @objc
    func resetRecords() {

        let alertViewController = UIAlertController(title: Constants.alertResetTitle,
                                                    message: nil,
                                                    preferredStyle: .alert)

        alertViewController.addAction(UIAlertAction(title: Constants.alertCancel,
                                                    style: .cancel))

        alertViewController.addAction(UIAlertAction(title: Constants.alertReset,
                                                    style: .destructive,
                                                    handler: {  (_) in FNMNetworkMonitor.shared.clear { } }))

        self.navigationController?.present(alertViewController, animated: true)
    }

    @objc
    func exportViaEmail() {

        if MFMailComposeViewController.canSendMail() {

            var encodedRecordsDataSlim: Data?
            var encodedRecordsDataDetailed: Data?

            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = .prettyPrinted // Inefficient but the file size difference isn't significant

            do {

                let allDetails = self.allRecords.compactMap { return FNMRecordDetailInfo(record: $0) }

                encodedRecordsDataSlim = try jsonEncoder.encode(self.allRecords)
                encodedRecordsDataDetailed = try jsonEncoder.encode(allDetails)

            } catch {

            }

            if let encodedRecordsDataSlim = encodedRecordsDataSlim {

                let date = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy HH:mm:ss.SSS"

                let displayDate = formatter.string(from: date)
                let displayName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""

                let mail = MFMailComposeViewController()
                mail.mailComposeDelegate = self
                mail.setSubject("Monitor Requests Exported at \(displayDate) for '\(displayName)'")

                mail.addAttachmentData(encodedRecordsDataSlim,
                                       mimeType: Constants.exportMime,
                                       fileName: Constants.exportSlimFilename)

                if let encodedRecordsDataDetailed = encodedRecordsDataDetailed {

                    mail.addAttachmentData(encodedRecordsDataDetailed,
                                           mimeType: Constants.exportMime,
                                           fileName: Constants.exportDetailedFilename)
                }

                present(mail, animated: true)

            } else {

                assertionFailure("Failed to encode, please advise")
            }

        } else {

            let alertViewController = UIAlertController(title: Constants.alertExportTitle,
                                                        message: nil,
                                                        preferredStyle: .alert)
            alertViewController.addAction(UIAlertAction(title: Constants.alertDismiss,
                                                        style: .cancel))

            self.navigationController?.present(alertViewController, animated: true)
        }
    }

    @objc
    func back() {

        self.navigationController?.popViewController(animated: true)
    }
}

// MARK: - FNMNetworkMonitorObserver

extension FNMDebugListingViewController: FNMNetworkMonitorObserver {

    func recordsUpdated(records: [FNMHTTPRequestRecord]) {

        self.updateAllRecords(to: records)
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension FNMDebugListingViewController: MFMailComposeViewControllerDelegate {

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {

        controller.dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource

extension FNMDebugListingViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return self.filteredRecords.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if self.filteredRecords.count > indexPath.row,
            let cell = tableView.dequeueReusableCell(withIdentifier: FNMDebugSummaryTableViewCell.reuseIdentifier(),
                                                                                for: indexPath) as? FNMDebugSummaryTableViewCell {

            let requestRecord = self.filteredRecords[indexPath.row]

            cell.configure(with: requestRecord)

            return cell
        }

        return UITableViewCell()
    }
}

// MARK: - UITableViewDelegate

extension FNMDebugListingViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if self.filteredRecords.count > indexPath.row {

            let requestRecord = self.filteredRecords[indexPath.row]
            let detailViewController = FNMDebugDetailViewController(record: requestRecord)
            self.navigationController?.pushViewController(detailViewController,
                                                          animated: true)
        }
    }
}

// MARK: - UISearchBarDelegate

extension FNMDebugListingViewController: UISearchBarDelegate {

    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {

        self.updateFilteredValues()
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {

        searchBar.resignFirstResponder()
    }
}
