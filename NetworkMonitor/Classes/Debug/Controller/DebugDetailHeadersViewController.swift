//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation
import UIKit

final class DebugDetailHeadersViewController: UIViewController, HighlightReloadable {

    // MARK: Properties

    let recordHeaderDetailInfo: RecordHeaderDetailInfo

    private let tableView = UITableView(frame: .zero,
                                            style: .plain)

    var highlight: String = ""

    // MARK: - Lifecycle

    init(recordHeaderDetailInfo: RecordHeaderDetailInfo) {

        self.recordHeaderDetailInfo = recordHeaderDetailInfo

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

    // MARK: Public

    func reloadData(with highlight: String?) {

        self.highlight = highlight ?? ""

        self.tableView.reloadData()
    }
}

// MARK: - DebugDetailHeadersViewController: Layout

private extension DebugDetailHeadersViewController {

    // MARK: - Constants

    enum Constants {

        static let tableViewEstimatedHeight: CGFloat = 60.0
    }

    // MARK: - Layout Configuration

    func configureViews() {

        self.configureTableView()
    }

    func configureTableView() {

        self.tableView.register(FNMDebugSummaryTableViewCell.self,
                                forCellReuseIdentifier: FNMDebugSummaryTableViewCell.reuseIdentifier())
        self.tableView.register(FNMDebugDetailInfoTableViewCell.self,
                                forCellReuseIdentifier: FNMDebugDetailInfoTableViewCell.reuseIdentifier())
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = Constants.tableViewEstimatedHeight
        self.tableView.separatorInset = UIEdgeInsets.zero
        self.tableView.keyboardDismissMode = .onDrag
        self.tableView.backgroundColor = .white

        self.view.addSubview(self.tableView)

        let guide: UILayoutGuide

        if #available(iOS 11.0, *) {

            guide = self.view.safeAreaLayoutGuide

        } else {

            guide = self.view.readableContentGuide
        }

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.topAnchor.constraint(equalTo: guide.topAnchor).isActive = true
        self.tableView.bottomAnchor.constraint(equalTo: guide.bottomAnchor).isActive = true
        self.tableView.leadingAnchor.constraint(equalTo: guide.leadingAnchor).isActive = true
        self.tableView.trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true

        self.tableView.dataSource = self
        self.tableView.delegate = self
    }
}

// MARK: - DebugDetailHeadersViewController: UITableViewDataSource

extension DebugDetailHeadersViewController: UITableViewDataSource {

    enum DebugDetailViewControllerSection: Int {

        case summary = 0
        case requestHeaders = 1
        case responseHeaders = 2
        case total = 3

        func headerTitle() -> String? {

            switch self {
            case .summary: return "Summary"
            case .requestHeaders: return "Request Headers"
            case .responseHeaders: return "Response Headers"
            default: return nil
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        guard let section = DebugDetailViewControllerSection(rawValue: section) else { return 0 }

        switch section {
        case .summary: return 1
        case .requestHeaders: return self.recordHeaderDetailInfo.requestHeaders.count
        case .responseHeaders: return self.recordHeaderDetailInfo.responseHeaders.count
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if let section = DebugDetailViewControllerSection(rawValue: indexPath.section) {

            switch section {
            case .summary:

                if let cell = tableView.dequeueReusableCell(withIdentifier: FNMDebugSummaryTableViewCell.reuseIdentifier(),
                                                            for: indexPath) as? FNMDebugSummaryTableViewCell {

                    cell.configure(with: self.recordHeaderDetailInfo.record)

                    return cell
                }

            case .requestHeaders:

                if let cell = tableView.dequeueReusableCell(withIdentifier: FNMDebugDetailInfoTableViewCell.reuseIdentifier(),
                                                            for: indexPath) as? FNMDebugDetailInfoTableViewCell,
                    self.recordHeaderDetailInfo.requestHeaders.count > indexPath.row {

                    cell.configure(with: self.recordHeaderDetailInfo.requestHeaders[indexPath.row],
                                   highlight: self.highlight,
                                   typeIndicatorColor: UIColor.cyan)

                    return cell
                }

            case .responseHeaders:

                if let cell = tableView.dequeueReusableCell(withIdentifier: FNMDebugDetailInfoTableViewCell.reuseIdentifier(),
                                                            for: indexPath) as? FNMDebugDetailInfoTableViewCell,
                    self.recordHeaderDetailInfo.responseHeaders.count > indexPath.row {

                    cell.configure(with: self.recordHeaderDetailInfo.responseHeaders[indexPath.row],
                                   highlight: self.highlight,
                                   typeIndicatorColor: UIColor.orange)

                    return cell
                }

            default: break
            }
        }

        return UITableViewCell()
    }

    func numberOfSections(in tableView: UITableView) -> Int {

        return DebugDetailViewControllerSection.total.rawValue
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {

        return DebugDetailViewControllerSection(rawValue: section)?.headerTitle()
    }
}

// MARK: - DebugDetailHeadersViewController: UITableViewDelegate

extension DebugDetailHeadersViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {

        return false
    }
}
