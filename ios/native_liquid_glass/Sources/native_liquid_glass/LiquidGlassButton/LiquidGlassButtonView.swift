import Flutter
import SwiftUI
import UIKit

/// Platform-view bridge for Liquid Glass button widgets.
final class LiquidGlassButtonPlatformView: NSObject, FlutterPlatformView {
  private let containerView: UIView
  private let methodChannel: FlutterMethodChannel
  private let defaultIconOnly: Bool
  private var forceShow = false

  // SwiftUI path (iOS 16+)
  private var viewModel: AnyObject?
  private var hostingController: UIViewController?

  // UIKit legacy path (iOS < 16)
  private var legacyButton: UIButton?
  private var legacyConfig: LiquidGlassButtonConfig?
  private var suppressObserver: GlassSuppressObserver?
  private var isRouteSuppressed = false
  private var isPopupRouteSuppressed = false

  init(
    frame: CGRect,
    viewId: Int64,
    arguments args: [String: Any]?,
    messenger: FlutterBinaryMessenger,
    defaultIconOnly: Bool
  ) {
    self.defaultIconOnly = defaultIconOnly

    methodChannel = FlutterMethodChannel(
      name:
        "\(defaultIconOnly ? "liquid-glass-icon-button-view" : "liquid-glass-button-view")/\(viewId)",
      binaryMessenger: messenger
    )

    containerView = UIView(frame: frame)
    containerView.backgroundColor = .clear
    containerView.clipsToBounds = false

    super.init()
    // Buttons should remain visible beneath Flutter modals, but stop
    // accepting taps until the route becomes current again.
    suppressObserver = GlassSuppressObserver(view: containerView, hidesView: false)

    if #available(iOS 16.0, *) {
      configureSwiftUI(args: args)
    } else {
      configureLegacyUIKit(args: args)
    }

    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "getIntrinsicSize":
        if #available(iOS 16.0, *) {
          self.hostingController?.view.setNeedsLayout()
          self.hostingController?.view.layoutIfNeeded()
          let size =
            self.hostingController?.view.systemLayoutSizeFitting(
              UIView.layoutFittingCompressedSize)
            ?? CGSize(width: 100, height: 50)
          result(["width": Double(size.width), "height": Double(size.height)])
        } else {
          self.legacyButton?.setNeedsLayout()
          self.legacyButton?.layoutIfNeeded()
          let size = self.legacyButton?.intrinsicContentSize ?? CGSize(width: 100, height: 50)
          result(["width": Double(size.width), "height": Double(size.height)])
        }

      case "updateConfig":
        let newArgs = call.arguments as? [String: Any]
        let newConfig = LiquidGlassButtonConfig(
          arguments: newArgs, defaultIconOnly: self.defaultIconOnly)
        if #available(iOS 16.0, *) {
          if let vm = self.viewModel as? LiquidGlassButtonViewModel {
            vm.config = newConfig
          }
          DispatchQueue.main.async {
            self.hostingController?.view.setNeedsLayout()
            self.hostingController?.view.layoutIfNeeded()
            let size =
              self.hostingController?.view.systemLayoutSizeFitting(
                UIView.layoutFittingCompressedSize)
              ?? CGSize(width: 100, height: 50)
            result(["width": Double(size.width), "height": Double(size.height)])
          }
        } else {
          self.legacyConfig = newConfig
          self.applyLegacyConfiguration()
          self.legacyButton?.setNeedsLayout()
          self.legacyButton?.layoutIfNeeded()
          let size = self.legacyButton?.intrinsicContentSize ?? CGSize(width: 100, height: 50)
          result(["width": Double(size.width), "height": Double(size.height)])
        }

      case "setEnabled":
        let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? true
        if #available(iOS 16.0, *) {
          if let vm = self.viewModel as? LiquidGlassButtonViewModel {
            vm.config = vm.config.withEnabled(enabled)
          }
        } else {
          self.legacyButton?.isEnabled = enabled
          if let config = self.legacyConfig {
            self.legacyConfig = config.withEnabled(enabled)
          }
        }
        result(nil)
      case "setForceShow":
        let forceShow = (call.arguments as? [String: Any])?["forceShow"] as? Bool ?? false
        self.forceShow = forceShow
        if #available(iOS 16.0, *) {
          if let vm = self.viewModel as? LiquidGlassButtonViewModel {
            vm.forceShow = forceShow
          }
        } else {
          self.applyLegacyConfiguration()
        }
        self.suppressObserver?.setForceShow(forceShow)
        result(nil)
      case "setSuppressed":
        let suppressed = (call.arguments as? [String: Any])?["suppressed"] as? Bool ?? false
        let reason = (call.arguments as? [String: Any])?["reason"] as? String

        // If forceShow is true, ignore suppression
        let shouldSuppress = !self.forceShow && suppressed

        self.isRouteSuppressed = shouldSuppress
        self.isPopupRouteSuppressed = shouldSuppress && reason == "popup"

        if #available(iOS 16.0, *) {
          if let vm = self.viewModel as? LiquidGlassButtonViewModel {
            vm.isRouteSuppressed = shouldSuppress
            vm.isPopupRouteSuppressed = shouldSuppress && reason == "popup"
          }
        } else {
          self.applyLegacyConfiguration()
        }

        let style: GlassSuppressObserver.RouteSuppressionStyle =
          (reason == "popup") ? .disabled : .hidden
        self.suppressObserver?.setRouteSuppressed(shouldSuppress, style: style)
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  func setForceShow(_ force: Bool) {
    forceShow = force
    suppressObserver?.setForceShow(force)

    if #available(iOS 16.0, *) {
      if let vm = viewModel as? LiquidGlassButtonViewModel {
        vm.forceShow = force
        // Re-evaluate suppressed state
        let shouldBeSuppressed = !force && (isRouteSuppressed || isPopupRouteSuppressed)
        vm.isRouteSuppressed = shouldBeSuppressed && isRouteSuppressed
        vm.isPopupRouteSuppressed = shouldBeSuppressed && isPopupRouteSuppressed
      }
    } else {
      applyLegacyConfiguration()
    }
  }
  func view() -> UIView {
    containerView
  }

  // MARK: - SwiftUI setup (iOS 16+)

  @available(iOS 16.0, *)
  private func configureSwiftUI(args: [String: Any]?) {
    let config = LiquidGlassButtonConfig(arguments: args, defaultIconOnly: defaultIconOnly)
    let vm = LiquidGlassButtonViewModel(config: config)
    vm.onPressed = { [weak self] in
      guard let self, self.suppressObserver?.isInteractionSuppressed != true else { return }
      self.methodChannel.invokeMethod("onPressed", arguments: nil)
    }
    self.viewModel = vm

    let swiftUIView = LiquidGlassButtonRootView(viewModel: vm)
    let hc = UIHostingController(rootView: swiftUIView)
    hc.view.backgroundColor = .clear
    hc.view.translatesAutoresizingMaskIntoConstraints = false

    containerView.addSubview(hc.view)
    NSLayoutConstraint.activate([
      hc.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      hc.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      hc.view.topAnchor.constraint(equalTo: containerView.topAnchor),
      hc.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])

    hc.view.setNeedsLayout()
    hc.view.layoutIfNeeded()

    self.hostingController = hc
  }

  // MARK: - UIKit legacy setup (iOS < 16)

  private func configureLegacyUIKit(args: [String: Any]?) {
    let config = LiquidGlassButtonConfig(arguments: args, defaultIconOnly: defaultIconOnly)
    self.legacyConfig = config

    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.backgroundColor = .clear
    button.isEnabled = config.enabled && !isRouteSuppressed
    button.addTarget(self, action: #selector(handleLegacyButtonTap), for: .touchUpInside)

    self.legacyButton = button
    containerView.addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      button.topAnchor.constraint(equalTo: containerView.topAnchor),
      button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])

    applyLegacyConfiguration()
  }

  private func applyLegacyConfiguration() {
    guard let config = legacyConfig, let button = legacyButton else { return }

    let baseTintColor = config.tint ?? button.tintColor ?? .systemBlue
    let usesTemporaryProminentStyle =
      isPopupRouteSuppressed && !config.useLiquidGlassWhenPopupSuppressed
    let resolvedBackgroundColor =
      usesTemporaryProminentStyle
      ? baseTintColor
      : baseTintColor.withAlphaComponent(0.22)
    let resolvedForegroundColor =
      usesTemporaryProminentStyle
      ? .white
      : (config.foregroundColor ?? config.iconColor ?? .label)

    button.backgroundColor = resolvedBackgroundColor
    button.tintColor = config.iconColor ?? resolvedForegroundColor
    button.setTitleColor(resolvedForegroundColor, for: .normal)
    button.isEnabled = config.enabled && !isRouteSuppressed

    if config.iconOnly {
      button.setTitle(nil, for: .normal)
      button.contentEdgeInsets = .zero
      button.imageEdgeInsets = .zero
      button.titleEdgeInsets = .zero
    } else {
      button.setTitle(config.title ?? "Button", for: .normal)
      button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
      let halfPadding = config.imagePadding / 2
      button.imageEdgeInsets = UIEdgeInsets(
        top: 0, left: -halfPadding, bottom: 0, right: halfPadding)
      button.titleEdgeInsets = UIEdgeInsets(
        top: 0, left: halfPadding, bottom: 0, right: -halfPadding)
    }

    button.setImage(config.resolvedImage(), for: .normal)
    button.layoutIfNeeded()
    let cornerRadius =
      config.iconOnly
      ? min(button.bounds.width, button.bounds.height) / 2
      : min(config.height / 2, 16)
    button.layer.cornerRadius = cornerRadius > 0 ? cornerRadius : config.height / 2
    button.clipsToBounds = true
  }

  @objc
  private func handleLegacyButtonTap() {
    guard suppressObserver?.isInteractionSuppressed != true else { return }
    methodChannel.invokeMethod("onPressed", arguments: nil)
  }
}
