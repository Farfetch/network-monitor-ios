//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation
import UIKit

class FNMDebugSummaryTableViewCell: UITableViewCell {

    let statusIndicator = UIView()
    let metaLabel = UILabel()
    let separator = UIView()
    let urlLabel = UILabel()

    class func reuseIdentifier() -> String {

        return String(describing: type(of: self))
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        super.init(style: style,
                   reuseIdentifier: reuseIdentifier)

        self.configureSubviews()
    }

    required init?(coder aDecoder: NSCoder) {

        fatalError("init(coder:) has not been implemented")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {

        self.contentView.backgroundColor = .white
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {

        self.contentView.backgroundColor = highlighted ? .lightGray : .white
    }
}

extension FNMDebugSummaryTableViewCell {

    func configure(with requestRecord: FNMHTTPRequestRecord) {

        self.statusIndicator.backgroundColor = type(of: self).requestResponseTintColor(requestRecord.conclusion)
        self.configureMetaText(type(of: self).requestResponseMetaString(requestRecord))
        self.configureURLText(type(of: self).requestResponseURLString(requestRecord))
    }
}

extension FNMDebugSummaryTableViewCell {

    private enum Constants {

        static let cellFixedHeight: CGFloat = 80.0
        static let cellFontSize: CGFloat = 12.0
        static let statusIndicatorWidth: CGFloat = 8.0
        static let metaLabelWidth: CGFloat = 100.0
        static let separatorWidth: CGFloat = 1.0
        static let padding: CGFloat = 4.0
        static let negativePadding: CGFloat = Constants.padding * -1
        static let timeUnit = "ms"
        static let statUpArrowUnicode = "\u{2191}"
        static let statDownArrowUnicode = "\u{2193}"
        static let downArrowUnicode = "\u{25BC}"
        static let emSpaceUnicode = "\u{2003}"
        static let enSpaceUnicode = "\u{2002}"
    }

    func configureSubviews() {

        // Minimum height
        let heightConstraint = self.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.cellFixedHeight)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true

        self.contentView.addSubview(self.statusIndicator)
        self.contentView.addSubview(self.metaLabel)
        self.contentView.addSubview(self.separator)
        self.contentView.addSubview(self.urlLabel)

        self.statusIndicator.backgroundColor = .gray
        self.metaLabel.numberOfLines = 3
        self.separator.backgroundColor = .darkGray
        self.urlLabel.numberOfLines = 0

        let guide: UILayoutGuide

        if #available(iOS 11.0, *) {

            guide = self.contentView.safeAreaLayoutGuide

        } else {

            guide = self.contentView.readableContentGuide
        }

        self.statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.statusIndicator.topAnchor.constraint(equalTo: guide.topAnchor).isActive = true
        self.statusIndicator.bottomAnchor.constraint(equalTo: guide.bottomAnchor).isActive = true
        self.statusIndicator.leadingAnchor.constraint(equalTo: guide.leadingAnchor).isActive = true
        self.statusIndicator.widthAnchor.constraint(equalToConstant: Constants.statusIndicatorWidth).isActive = true

        self.metaLabel.translatesAutoresizingMaskIntoConstraints = false
        self.metaLabel.topAnchor.constraint(equalTo: guide.topAnchor).isActive = true
        self.metaLabel.bottomAnchor.constraint(equalTo: guide.bottomAnchor).isActive = true
        self.metaLabel.leadingAnchor.constraint(equalTo: self.statusIndicator.trailingAnchor, constant: Constants.padding).isActive = true
        self.metaLabel.widthAnchor.constraint(equalToConstant: Constants.metaLabelWidth).isActive = true

        self.separator.translatesAutoresizingMaskIntoConstraints = false
        self.separator.topAnchor.constraint(equalTo: guide.topAnchor).isActive = true
        self.separator.bottomAnchor.constraint(equalTo: guide.bottomAnchor).isActive = true
        self.separator.leadingAnchor.constraint(equalTo: self.metaLabel.trailingAnchor, constant: Constants.padding).isActive = true
        self.separator.widthAnchor.constraint(equalToConstant: Constants.separatorWidth).isActive = true

        self.urlLabel.translatesAutoresizingMaskIntoConstraints = false
        self.urlLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: Constants.padding).isActive = true
        self.urlLabel.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: Constants.negativePadding).isActive = true
        self.urlLabel.leadingAnchor.constraint(equalTo: self.separator.trailingAnchor, constant: Constants.padding).isActive = true
        self.urlLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: Constants.negativePadding).isActive = true
    }

    func configureMetaText(_ metaInfo: MetaInfo) {

        let titleAttributedText = NSMutableAttributedString(string: metaInfo.metaGeneralInfo)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byClipping

        let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: Constants.cellFontSize),
                                                              .kern: 0.0,
                                                              .baselineOffset: 0.0,
                                                              .foregroundColor: UIColor.black,
                                                              .paragraphStyle: style]

        titleAttributedText.addAttributes(titleAttributes, range: NSRange(location: 0, length: titleAttributedText.string.count))

        NSString(string: titleAttributedText.string).rangesOfSubstring(NSString(string: metaInfo.genericHighlightedInfo)).forEach {

            titleAttributedText.addAttributes([.font: UIFont.boldSystemFont(ofSize: Constants.cellFontSize)], range: $0)
        }

        if let statusCodeInfo = metaInfo.statusCodeInfo {

            NSString(string: titleAttributedText.string).rangesOfSubstring(NSString(string: statusCodeInfo.highlightedInfoText)).forEach {

                titleAttributedText.addAttributes([.font: UIFont.boldSystemFont(ofSize: Constants.cellFontSize), .foregroundColor: statusCodeInfo.HighlightedInfoColor], range: $0)
            }
        }

        self.metaLabel.attributedText = titleAttributedText
    }

    func configureURLText(_ string: String) {

        self.urlLabel.text = string
        self.urlLabel.textColor = .black
        self.urlLabel.textAlignment = .center
        self.urlLabel.font = UIFont.boldSystemFont(ofSize: Constants.cellFontSize)
        self.urlLabel.lineBreakMode = .byClipping
    }

    class func requestResponseTintColor(_ conclusion: FNMHTTPRequestRecordConclusionType?) -> UIColor {

        guard let conclusion = conclusion else { return .gray }

        switch conclusion {
        case .clientError(_):
            return .red
        case .redirected(_):
            return .cyan
        case .completed(_, let response, _):

            if let response = response,
                response.isSuccessful() {

                return .green

            } else {

                return .red
            }
        }
    }

    typealias MetaInfo = (metaGeneralInfo: MetaGeneralInfo,
                          genericHighlightedInfo: MetaGenericHighlightedInfo,
                          statusCodeInfo: MetaStatusCodeHighlightedInfo?)

    typealias MetaGeneralInfo = String
    typealias MetaGenericHighlightedInfo = String
    typealias MetaStatusCodeHighlightedInfo = (highlightedInfoText: String, HighlightedInfoColor: UIColor)

    class func requestResponseMetaString(_ requestRecord: FNMHTTPRequestRecord) -> MetaInfo {

        var metaGeneralInfo: MetaGeneralInfo = ""
        var genericHighlightedInfo: MetaGenericHighlightedInfo = ""
        var statusCodeHighlightedInfo: MetaStatusCodeHighlightedInfo?

        if let startTimestampDisplayRepresentation = requestRecord.startTimestamp.debugSummaryTableViewCellDisplayRepresentation(),
            let httpMethod = requestRecord.request.httpMethod {

            metaGeneralInfo.append(startTimestampDisplayRepresentation)
            metaGeneralInfo.append("\n")
            metaGeneralInfo.append(httpMethod)

            genericHighlightedInfo = httpMethod

            if let endTimestamp = requestRecord.endTimestamp,
                let timeDifference = (endTimestamp.timeIntervalSince1970 - requestRecord.startTimestamp.timeIntervalSince1970).debugSummaryTableViewCellDisplayRepresentation(),
                let conclusion = requestRecord.conclusion {

                metaGeneralInfo.append(Constants.emSpaceUnicode)
                metaGeneralInfo.append(timeDifference)
                metaGeneralInfo.append(Constants.enSpaceUnicode)
                metaGeneralInfo.append(Constants.timeUnit)

                if case FNMHTTPRequestRecordConclusionType.completed(_, let response, _) = conclusion,
                    let statusCode = response?.statusCode {

                    let statusCodeString = "\(statusCode)"

                    metaGeneralInfo.append("\n")
                    metaGeneralInfo.append(statusCodeString)

                    statusCodeHighlightedInfo = (statusCodeString, self.requestResponseTintColor(conclusion))
                }
            }
        }

        return (metaGeneralInfo, genericHighlightedInfo, statusCodeHighlightedInfo)
    }

    class func requestResponseURLString(_ requestRecord: FNMHTTPRequestRecord) -> String {

        guard let requestURL = requestRecord.request.url else { return "" }

        let requestSize = requestRecord.requestSize.byteString
        let responseSize = requestRecord.responseSize.byteString

        var text = """
            \(Constants.statUpArrowUnicode) \(requestSize) \(Constants.statDownArrowUnicode) \(responseSize)
        
            \(requestURL.absoluteString)
        """

        if let conclusion = requestRecord.conclusion,
            case FNMHTTPRequestRecordConclusionType.redirected(let newRequest) = conclusion,
            let newRequestURL = newRequest?.url {

            text.append("\n")
            text.append(Constants.downArrowUnicode)
            text.append("\n")
            text.append(newRequestURL.absoluteString)
        }

        return text.removingPercentEncoding ?? text
    }
}

private extension TimeInterval {

    private enum Constants {

        static let fractionDigits = 0
    }

    static let debugSummaryTableViewCellDisplayRepresentationFormatter: NumberFormatter = {

        let formatter = NumberFormatter()
        formatter.groupingSeparator = "."
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = Constants.fractionDigits

        return formatter
    }()

    func debugSummaryTableViewCellDisplayRepresentation() -> String? {

        return TimeInterval.debugSummaryTableViewCellDisplayRepresentationFormatter.string(from: NSNumber(value: self * 1000.0))
    }
}

private extension Date {

    static let debugSummaryTableViewCellDisplayRepresentationFormatter: DateFormatter = {

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        return formatter
    }()

    func debugSummaryTableViewCellDisplayRepresentation() -> String? {

        return Date.debugSummaryTableViewCellDisplayRepresentationFormatter.string(from: self)
    }
}
