//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation
import UIKit

class FNMDebugDetailInfoTableViewCell: UITableViewCell {

    private enum Constants {

        static let goldColor = UIColor(red: 196.0, green: 170.0, blue: 132.0, alpha: 1.0)
        static let cellFixedHeight: CGFloat = 60.0
        static let statusIndicatorWidth: CGFloat = 8.0
        static let padding: CGFloat = 4.0
        static let negativePadding: CGFloat = Constants.padding * -1
        static let cellFontSize: CGFloat = 15.0
    }

    let typeIndicator = UIView()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()

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
}

extension FNMDebugDetailInfoTableViewCell {

    func configure(with titleSubtitlePair: FNMTitleSubtitlePair,
                   highlight: String = "",
                   typeIndicatorColor: UIColor) {

        self.typeIndicator.backgroundColor = typeIndicatorColor

        let titleAttributedText = NSMutableAttributedString(string: titleSubtitlePair.title)
        let subtitleViewAttributedText = NSMutableAttributedString(string: titleSubtitlePair.subtitle)

        let titleRange = NSRange(location: 0, length: titleAttributedText.string.count)
        let subtitleRange = NSRange(location: 0, length: subtitleViewAttributedText.string.count)

        let style = NSMutableParagraphStyle()
        style.alignment = .natural

        let titleFont = UIFont.boldSystemFont(ofSize: Constants.cellFontSize)
        let subtitleFont = UIFont.systemFont(ofSize: Constants.cellFontSize)

        let generalAttributes: [NSAttributedString.Key: Any] = [.kern: 0.0,
                                                                .baselineOffset: 0.0,
                                                                .foregroundColor: UIColor.black,
                                                                .paragraphStyle: style]

        titleAttributedText.addAttributes(generalAttributes, range: titleRange)
        titleAttributedText.addAttributes([.font: titleFont], range: titleRange)
        subtitleViewAttributedText.addAttributes(generalAttributes, range: subtitleRange)
        subtitleViewAttributedText.addAttributes([.font: subtitleFont], range: subtitleRange)

        if highlight.count > 0 {

            NSString(string: titleAttributedText.string).rangesOfSubstring(NSString(string: highlight)).forEach {

                titleAttributedText.addAttributes([.backgroundColor: Constants.goldColor], range: $0)
            }

            NSString(string: subtitleViewAttributedText.string).rangesOfSubstring(NSString(string: highlight)).forEach {

                subtitleViewAttributedText.addAttributes([.backgroundColor: Constants.goldColor], range: $0)
            }
        }

        self.titleLabel.attributedText = titleAttributedText
        self.subtitleLabel.attributedText = subtitleViewAttributedText
    }
}

extension FNMDebugDetailInfoTableViewCell {

    func configureSubviews() {

        // Minimum height
        let heightConstraint = self.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.cellFixedHeight)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true

        self.contentView.backgroundColor = .white

        self.contentView.addSubview(self.typeIndicator)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.subtitleLabel)

        self.typeIndicator.backgroundColor = .gray
        self.titleLabel.numberOfLines = 1
        self.subtitleLabel.numberOfLines = 0

        let guide: UILayoutGuide

        if #available(iOS 11.0, *) {

            guide = self.contentView.safeAreaLayoutGuide

        } else {

            guide = self.contentView.readableContentGuide
        }

        self.typeIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.typeIndicator.topAnchor.constraint(equalTo: guide.topAnchor).isActive = true
        self.typeIndicator.bottomAnchor.constraint(equalTo: guide.bottomAnchor).isActive = true
        self.typeIndicator.leadingAnchor.constraint(equalTo: guide.leadingAnchor).isActive = true
        self.typeIndicator.widthAnchor.constraint(equalToConstant: Constants.statusIndicatorWidth).isActive = true

        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: Constants.padding).isActive = true
        self.titleLabel.leadingAnchor.constraint(equalTo: self.typeIndicator.trailingAnchor, constant: Constants.padding).isActive = true
        self.titleLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true

        self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.subtitleLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: Constants.padding).isActive = true
        self.subtitleLabel.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: Constants.negativePadding).isActive = true
        self.subtitleLabel.leadingAnchor.constraint(equalTo: self.typeIndicator.trailingAnchor, constant: Constants.padding).isActive = true
        self.subtitleLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true
    }
}
