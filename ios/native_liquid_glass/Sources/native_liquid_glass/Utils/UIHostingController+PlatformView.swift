import SwiftUI
import UIKit

extension UIHostingController {
  /// Prepares a hosting controller whose view is embedded in a Flutter
  /// platform view.
  ///
  /// By default a hosting controller insets its SwiftUI content by the
  /// window's safe area wherever its view overlaps it. A platform view laid
  /// out near the bottom (home indicator) or top (status bar) of the screen
  /// then draws its content shifted away from the edge, and keeps that offset
  /// after it scrolls elsewhere, so native content drifts off its Flutter
  /// layout slot inside scroll views. Flutter already handles safe areas, so
  /// the embedded content ignores them.
  func configureForFlutterPlatformView() {
    if #available(iOS 16.4, *) {
      safeAreaRegions = []
    }
    view.backgroundColor = .clear
  }
}
