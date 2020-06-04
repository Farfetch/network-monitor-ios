//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation
import UIKit

final class DebugDetailBodyViewController: UIViewController, HighlightReloadable {

    // MARK: Properties

    let recordBodyDetailInfo: RecordBodyDetailInfo

    private let titleLabel = UILabel()
    private let textView = UITextView()

    var highlight: String = ""

    // MARK: Lifecycle

    init(recordBodyDetailInfo: RecordBodyDetailInfo) {

        self.recordBodyDetailInfo = recordBodyDetailInfo

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

        self.reloadText()
    }
}

// MARK: - DebugDetailBodyViewController: Layout

private extension DebugDetailBodyViewController {

    // MARK: - Constants

    enum Constants {

           static let goldColor = UIColor(red: 196.0, green: 170.0, blue: 132.0, alpha: 1.0)
           static let titleLabelFontSize: CGFloat = 15.0
           static let textViewFontSize: CGFloat = 14.0
    }

    // MARK: - Layout Configuration

    func configureViews() {

        self.view.addSubview(self.titleLabel)
        self.view.addSubview(self.textView)
        self.textView.backgroundColor = .white

        let guide: UILayoutGuide

        if #available(iOS 11.0, *) {

            guide = self.view.safeAreaLayoutGuide

        } else {

            guide = self.view.readableContentGuide
        }

        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.topAnchor.constraint(equalTo: guide.topAnchor).isActive = true
        self.titleLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor).isActive = true
        self.titleLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true

        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor).isActive = true
        self.textView.bottomAnchor.constraint(equalTo: guide.bottomAnchor).isActive = true
        self.textView.leadingAnchor.constraint(equalTo: guide.leadingAnchor).isActive = true
        self.textView.trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true

        self.textView.isEditable = false

        self.reloadText()
    }

    func reloadText() {

        let titleAttributedText = NSMutableAttributedString(string: self.recordBodyDetailInfo.body.title)
        let style = NSMutableParagraphStyle()
        style.alignment = .natural

        let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: Constants.titleLabelFontSize),
                                                              .kern: 0.0,
                                                              .baselineOffset: 0.0,
                                                              .foregroundColor: UIColor.black,
                                                              .paragraphStyle: style]

        titleAttributedText.addAttributes(titleAttributes, range: NSRange(location: 0, length: titleAttributedText.string.count))

        NSString(string: titleAttributedText.string).rangesOfSubstring(NSString(string: self.highlight)).forEach {

            titleAttributedText.addAttributes([.backgroundColor: Constants.goldColor], range: $0)
        }

        self.textView.attributedText = titleAttributedText

        let textViewAttributedText = NSMutableAttributedString(string: self.recordBodyDetailInfo.body.subtitle)

        let textViewAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: Constants.textViewFontSize),
                                                                 .kern: 0.0,
                                                                 .baselineOffset: 0.0,
                                                                 .foregroundColor: UIColor.black]

        textViewAttributedText.addAttributes(textViewAttributes, range: NSRange(location: 0, length: textViewAttributedText.string.count))

        if self.highlight.count > 0 {

            NSString(string: textViewAttributedText.string).rangesOfSubstring(NSString(string: self.highlight)).forEach {

                textViewAttributedText.addAttributes([.backgroundColor: Constants.goldColor], range: $0)
            }
        }

        self.textView.attributedText = textViewAttributedText
    }
}
