import Flutter
import SwiftUI
import UIKit

/// Platform view for Liquid Glass text field
public class LiquidGlassTextFieldPlatformView: NSObject, FlutterPlatformView {
    private let containerView: IntrinsicSizeView
    private let methodChannel: FlutterMethodChannel
    private var hostingController: UIViewController?
    private var suppressObserver: GlassSuppressObserver?
    private var legacyTextField: UITextField?
    private var currentConfig: LiquidGlassTextFieldConfig?

    public init(
        frame: CGRect, viewId: Int64, arguments args: [String: Any]?,
        messenger: FlutterBinaryMessenger
    ) {
        methodChannel = FlutterMethodChannel(
            name: "liquid-glass-text-field-view/\(viewId)",
            binaryMessenger: messenger
        )

        containerView = IntrinsicSizeView(frame: frame)
        containerView.backgroundColor = .clear
        containerView.clipsToBounds = false

        super.init()

        suppressObserver = GlassSuppressObserver(view: containerView, hidesView: false)

        if #available(iOS 16.0, *) {
            configureSwiftUI(args: args)
        } else {
            configureLegacyUIKit(args: args)
        }

        setupMethodChannel()
    }

    public func view() -> UIView {
        containerView
    }

    private func setupMethodChannel() {
        methodChannel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }

            switch call.method {
            case "updateConfig":
                let args = call.arguments as? [String: Any]
                if #available(iOS 16.0, *) {
                    self.updateSwiftUIConfig(args: args)
                } else {
                    self.updateLegacyConfig(args: args)
                }
                result(nil)

            case "setText":
                let text = (call.arguments as? [String: Any])?["text"] as? String ?? ""
                self.setText(text)
                result(nil)

            case "setSuppressed":
                let suppressed = (call.arguments as? [String: Any])?["suppressed"] as? Bool ?? false
                let reason = (call.arguments as? [String: Any])?["reason"] as? String
                let style: GlassSuppressObserver.RouteSuppressionStyle =
                    (reason == "popup") ? .disabled : .hidden
                self.suppressObserver?.setRouteSuppressed(suppressed, style: style)
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    @available(iOS 16.0, *)
    private func configureSwiftUI(args: [String: Any]?) {
        let config = LiquidGlassTextFieldConfig(arguments: args)
        let view = LiquidGlassTextFieldView(
            config: config,
            onChanged: { [weak self] text in
                self?.methodChannel.invokeMethod("onChanged", arguments: text)
            },
            onSubmit: { [weak self] text in
                self?.methodChannel.invokeMethod("onSubmit", arguments: text)
            },
            onEditingStart: { [weak self] in
                self?.methodChannel.invokeMethod("onEditingStart", arguments: nil)
            },
            onEditingEnd: { [weak self] in
                self?.methodChannel.invokeMethod("onEditingEnd", arguments: nil)
            },
            onPrefixIconTap: { [weak self] in
                self?.methodChannel.invokeMethod("onPrefixIconTap", arguments: nil)
            },
            onSuffixIconTap: { [weak self] in
                self?.methodChannel.invokeMethod("onSuffixIconTap", arguments: nil)
            },
            onSizeChanged: { [weak self] size in
                // Send size update to Flutter
                self?.methodChannel.invokeMethod(
                    "onSizeChanged",
                    arguments: [
                        "height": size.height,
                        "width": size.width,
                    ])
            }
        )

        let hc = UIHostingController(rootView: view)
        hc.view.backgroundColor = .clear
        hc.view.translatesAutoresizingMaskIntoConstraints = false

        // Allow the view to size itself
        hc.view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hc.view.setContentHuggingPriority(.defaultLow, for: .vertical)
        hc.view.setContentCompressionResistancePriority(.required, for: .vertical)
        hc.view.setContentCompressionResistancePriority(.required, for: .horizontal)

        containerView.addSubview(hc.view)

        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        hostingController = hc

        containerView.setNeedsLayout()
        containerView.layoutIfNeeded()

        // Send initial size
        DispatchQueue.main.async {
            self.methodChannel.invokeMethod(
                "onSizeChanged",
                arguments: [
                    "height": hc.view.frame.height,
                    "width": hc.view.frame.width,
                ])
        }

        if config.autoFocus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.findTextFieldInView(hc.view)?.becomeFirstResponder()
            }
        }
    }
    @available(iOS 16.0, *)
    private func updateSwiftUIConfig(args: [String: Any]?) {
        let newConfig = LiquidGlassTextFieldConfig(arguments: args)
        let view = LiquidGlassTextFieldView(
            config: newConfig,
            onChanged: { [weak self] text in
                self?.methodChannel.invokeMethod("onChanged", arguments: text)
            },
            onSubmit: { [weak self] text in
                self?.methodChannel.invokeMethod("onSubmit", arguments: text)
            },
            onEditingStart: { [weak self] in
                self?.methodChannel.invokeMethod("onEditingStart", arguments: nil)
            },
            onEditingEnd: { [weak self] in
                self?.methodChannel.invokeMethod("onEditingEnd", arguments: nil)
            },
            onPrefixIconTap: { [weak self] in
                self?.methodChannel.invokeMethod("onPrefixIconTap", arguments: nil)
            },
            onSuffixIconTap: { [weak self] in
                self?.methodChannel.invokeMethod("onSuffixIconTap", arguments: nil)
            },
            onSizeChanged: { [weak self] size in
                self?.invalidateIntrinsicContentSize()
            }
        )

        if let hc = hostingController as? UIHostingController<LiquidGlassTextFieldView> {
            hc.rootView = view
            hc.view.setNeedsLayout()
            containerView.setNeedsLayout()
            containerView.layoutIfNeeded()

            DispatchQueue.main.async {
                hc.view.setNeedsDisplay()
                self.containerView.setNeedsLayout()
                self.containerView.layoutIfNeeded()
                self.invalidateIntrinsicContentSize()
            }
        }
    }

    private func invalidateIntrinsicContentSize() {
        DispatchQueue.main.async { [weak self] in
            self?.containerView.invalidateIntrinsicContentSize()
            self?.methodChannel.invokeMethod(
                "onSizeChanged",
                arguments: [
                    "height": self?.containerView.intrinsicContentSize.height ?? 0
                ])
        }
    }

    // MARK: - Legacy UIKit (iOS < 16)

    private func configureLegacyUIKit(args: [String: Any]?) {
        let config = LiquidGlassTextFieldConfig(arguments: args)
        currentConfig = config

        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self

        containerView.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textField.topAnchor.constraint(equalTo: containerView.topAnchor),
            textField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        legacyTextField = textField
        applyLegacyConfig(config)

        if config.autoFocus {
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
            }
        }
    }

    private func updateLegacyConfig(args: [String: Any]?) {
        let config = LiquidGlassTextFieldConfig(arguments: args)
        currentConfig = config
        applyLegacyConfig(config)
    }

    private func applyLegacyConfig(_ config: LiquidGlassTextFieldConfig) {
        guard let textField = legacyTextField else { return }

        textField.text = config.text
        textField.placeholder = config.hint
        textField.isEnabled = config.enabled && !config.readOnly

        let isSecure = config.inputType == "password" || config.secureTextEntry
        if textField.isSecureTextEntry != isSecure {
            textField.isSecureTextEntry = isSecure
            textField.reloadInputViews()
            textField.setNeedsLayout()
            textField.layoutIfNeeded()
        }

        textField.keyboardType = keyboardType(for: config.inputType)
        textField.returnKeyType = returnKeyType(for: config.textInputAction)
        textField.textAlignment = textAlignment(for: config.textAlign)
        textField.font = config.textStyle?.resolvedFont()

        let hasError = config.errorText != nil
        let isFocused = textField.isFirstResponder

        textField.layer.cornerRadius = config.borderRadius ?? 8
        textField.layer.borderWidth =
            hasError ? 1.5 : (config.borderWidth > 0 ? config.borderWidth : 0.5)
        textField.layer.borderColor =
            borderColor(for: config, hasError: hasError, isFocused: isFocused).cgColor
        textField.backgroundColor =
            config.backgroundColor ?? (config.style == "rounded" ? .systemGray6 : .clear)

        if #available(iOS 17.0, *) {
            let style = config.magnifierStyle ?? .glass
            textField.magnifierStyle = style
        }

        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 10))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = paddingView
        textField.rightViewMode = .always
    }

    private func setText(_ text: String) {
        if #available(iOS 16.0, *) {
            if let hc = hostingController as? UIHostingController<LiquidGlassTextFieldView> {
                var view = hc.rootView
                view.text = text
                hc.rootView = view
            }
        } else {
            legacyTextField?.text = text
        }
    }

    private func keyboardType(for inputType: String) -> UIKeyboardType {
        switch inputType {
        case "email": return .emailAddress
        case "number": return .numberPad
        case "phone": return .phonePad
        case "url": return .URL
        case "name": return .namePhonePad
        default: return .default
        }
    }

    private func returnKeyType(for action: Int) -> UIReturnKeyType {
        switch action {
        case 1: return .next
        case 2: return .search
        case 3: return .send
        case 4: return .continue
        case 5: return .join
        case 6: return .route
        default: return .done
        }
    }

    private func textAlignment(for align: Int) -> NSTextAlignment {
        switch align {
        case 1: return .center
        case 2: return .right
        default: return .left
        }
    }

    private func borderColor(
        for config: LiquidGlassTextFieldConfig, hasError: Bool, isFocused: Bool
    ) -> UIColor {
        if hasError { return .red }
        if isFocused, let tint = config.tint { return tint }
        return config.borderColorValue ?? .systemGray4
    }

    private func findTextFieldInView(_ view: UIView) -> UITextField? {
        if let textField = view as? UITextField {
            return textField
        }
        for subview in view.subviews {
            if let found = findTextFieldInView(subview) {
                return found
            }
        }
        return nil
    }
}

extension LiquidGlassTextFieldPlatformView: UITextFieldDelegate {
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        methodChannel.invokeMethod("onEditingStart", arguments: nil)

        if let config = currentConfig {
            textField.layer.borderColor =
                borderColor(for: config, hasError: false, isFocused: true).cgColor
        }
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        methodChannel.invokeMethod("onEditingEnd", arguments: nil)

        if let config = currentConfig {
            textField.layer.borderColor =
                borderColor(for: config, hasError: false, isFocused: false).cgColor
        }
    }

    public func textField(
        _ textField: UITextField, shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let newText =
            (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string

        if let maxLength = currentConfig?.maxLength, newText.count > maxLength {
            return false
        }

        if let pattern = currentConfig?.validationPattern,
            let regex = try? NSRegularExpression(pattern: pattern),
            !newText.isEmpty
        {
            let range = NSRange(location: 0, length: newText.utf16.count)
            if regex.firstMatch(in: newText, range: range) == nil {
                return false
            }
        }

        methodChannel.invokeMethod("onChanged", arguments: newText)
        return true
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        methodChannel.invokeMethod("onSubmit", arguments: textField.text)
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Intrinsic Size View

class IntrinsicSizeView: UIView {
    override var intrinsicContentSize: CGSize {
        // Calculate based on subviews
        var height: CGFloat = 0
        for subview in subviews {
            let subviewHeight = subview.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
                .height
            height = max(height, subviewHeight)
        }
        return CGSize(
            width: UIView.noIntrinsicMetric, height: height > 0 ? height : UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}
