//
// Copyright (c) 2020, Farfetch.
// All rights reserved.
//
// This source code is licensed under the MIT-style license found in the
// LICENSE file in the root directory of this source tree.
//

import Foundation
import UIKit

class FNMViewController: UIViewController {}

extension FNMViewController {

    static func defaults() -> UserDefaults { return UserDefaults.standard }
}

extension FNMViewController {

    override open func motionEnded(_ motion: UIEvent.EventSubtype,
                                   with event: UIEvent?) {

        if motion == .motionShake {

            FNMNetworkMonitor.shared.dismissDebugListingViewController(currentNavigationController: self.navigationController)
        }
    }
}

extension FNMViewController {

    func forceSearchBarTextColor(_ searchBar: UISearchBar) {

        if #available(iOS 13.0, *) {

            searchBar.searchTextField.textColor = .black

        } else {

            let subviewsOfSubviews = searchBar.subviews.flatMap { $0.subviews }

            let searchTextField = (subviewsOfSubviews.first(where: { $0 is UITextField })) as? UITextField

            searchTextField?.textColor = .black
        }
    }
}
