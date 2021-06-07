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
    private lazy var textView = UITextView()
    private lazy var imageView = UIImageView()

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

           static let goldColor = UIColor(red: 196.0/255, green: 170.0/255, blue: 132.0/255, alpha: 1.0)
           static let titleLabelMinHeight: CGFloat = 25.0
           static let textViewFontSize: CGFloat = 14.0
    }

    // MARK: - Layout Configuration
    func configureViews() {

        let guide: UILayoutGuide

        if #available(iOS 11.0, *) {

            guide = self.view.safeAreaLayoutGuide

        } else {

            guide = self.view.readableContentGuide
        }

        self.view.addSubview(self.titleLabel)

        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.topAnchor.constraint(equalTo: guide.topAnchor).isActive = true
        self.titleLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor).isActive = true
        self.titleLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true
        self.titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.titleLabelMinHeight).isActive = true

        switch self.recordBodyDetailInfo.body.contentType {
        
        case .text(_):
            
            self.view.addSubview(self.textView)

            self.textView.translatesAutoresizingMaskIntoConstraints = false
            self.textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor).isActive = true
            self.textView.bottomAnchor.constraint(equalTo: guide.bottomAnchor).isActive = true
            self.textView.leadingAnchor.constraint(equalTo: guide.leadingAnchor).isActive = true
            self.textView.trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true

        case .image(_):

            self.view.addSubview(self.imageView)

            self.imageView.translatesAutoresizingMaskIntoConstraints = false
            self.imageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor).isActive = true
            self.imageView.bottomAnchor.constraint(equalTo: guide.bottomAnchor).isActive = true
            self.imageView.leadingAnchor.constraint(equalTo: guide.leadingAnchor).isActive = true
            self.imageView.trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true
        }

        self.reloadText()
    }

    func reloadText() {
        
        switch self.recordBodyDetailInfo.body.contentType {
        
        case .text(let data):

            self.titleLabel.text = self.recordBodyDetailInfo.body.title

            self.textView.isEditable = false
            self.textView.backgroundColor = .white

            let textViewAttributedText = NSMutableAttributedString(string: data)

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
            
        case .image(let data):

            self.titleLabel.text = "\(self.recordBodyDetailInfo.body.title) Image (\(Int(data.size.width))x\(Int(data.size.height)))"

            self.imageView.contentMode = .scaleAspectFit
            self.imageView.image = data
        }
    }
}
