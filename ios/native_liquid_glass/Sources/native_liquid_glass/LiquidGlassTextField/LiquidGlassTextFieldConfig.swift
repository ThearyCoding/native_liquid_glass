import Flutter
import UIKit
import SVGKit

/// Configuration for Liquid Glass text field
public struct LiquidGlassTextFieldConfig {
    public let text: String?
    public let hint: String?
    public let label: String?
    public let enabled: Bool
    public let readOnly: Bool
    public let required: Bool
    public let style: String
    public let inputType: String
    public let contentType: String
    public let maxLines: Int?
    public let minLines: Int?
    public let validationPattern: String?
    public let errorText: String?
    public let helperText: String?
    public let counterText: String?
    public let width: CGFloat?
    public let height: CGFloat?
    public let textAlign: Int
    public let tint: UIColor?
    public let backgroundColor: UIColor?
    public let borderColor: UIColor?
    public let borderRadius: CGFloat?
    public let iconSize: CGFloat
    public let textInputAction: Int
    public let glassEffectId: String?
    public let maxLength: Int?
    public let autoFocus: Bool
    public let contentInsets: NSDirectionalEdgeInsets?
    public let textStyle: TextFieldLabelStyle?
    public let hintStyle: TextFieldLabelStyle?
    public let labelStyle: TextFieldLabelStyle?
     public let secureTextEntry: Bool
    public let prefixSfSymbol: String?
    public let prefixIconData: Data?
    public let prefixAssetIcon: Data?
    public let suffixSfSymbol: String?
    public let suffixIconData: Data?
    public let suffixAssetIcon: Data?
    public let prefixIconColor: UIColor?
    public let suffixIconColor: UIColor?
    public let borderColorValue: UIColor?
    public let borderWidth: CGFloat
    public let magnifierStyle: MagnifierStyle?  

    public struct TextFieldLabelStyle {
        public let fontSize: CGFloat?
        public let fontWeight: UIFont.Weight?
        public let fontFamily: String?
        public let letterSpacing: CGFloat?
        public let color: UIColor?
        
        public init?(arguments args: [String: Any]?) {
            guard let args else { return nil }
            fontSize = (args["fontSize"] as? NSNumber).map { CGFloat(truncating: $0) }
            fontWeight = (args["fontWeight"] as? NSNumber).map { Self.mapFontWeight($0.intValue) }
            fontFamily = (args["fontFamily"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            letterSpacing = (args["letterSpacing"] as? NSNumber).map { CGFloat(truncating: $0) }
            color = Self.decodeColor(from: args["color"])
        }
        
        public func resolvedFont(defaultSize: CGFloat = 17.0) -> UIFont? {
            let pointSize = fontSize ?? defaultSize
            if let fontFamily, let customFont = UIFont(name: fontFamily, size: pointSize) {
                return customFont
            }
            if let fontWeight { return UIFont.systemFont(ofSize: pointSize, weight: fontWeight) }
            if fontSize != nil || fontFamily != nil { return UIFont.systemFont(ofSize: pointSize) }
            return nil
        }
        
        private static func mapFontWeight(_ value: Int) -> UIFont.Weight {
            switch value {
            case ...100: return .ultraLight
            case ...200: return .thin
            case ...300: return .light
            case ...400: return .regular
            case ...500: return .medium
            case ...600: return .semibold
            case ...700: return .bold
            case ...800: return .heavy
            default: return .black
            }
        }
        
        private static func decodeColor(from value: Any?) -> UIColor? {
            guard let numericValue = value as? NSNumber else { return nil }
            let argb = UInt32(bitPattern: Int32(truncatingIfNeeded: numericValue.intValue))
            let alpha = CGFloat((argb >> 24) & 0xFF) / 255.0
            let red = CGFloat((argb >> 16) & 0xFF) / 255.0
            let green = CGFloat((argb >> 8) & 0xFF) / 255.0
            let blue = CGFloat(argb & 0xFF) / 255.0
            return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        }
    }
    
    public init(arguments args: [String: Any]?) {
        text = (args?["text"] as? String) ?? ""
        hint = (args?["hint"] as? String)
        label = (args?["label"] as? String)
        enabled = (args?["enabled"] as? Bool) ?? true
        readOnly = (args?["readOnly"] as? Bool) ?? false
        required = (args?["required"] as? Bool) ?? false
        style = (args?["style"] as? String) ?? "glass"
        inputType = (args?["inputType"] as? String) ?? "text"
        contentType = (args?["contentType"] as? String) ?? "none"
        maxLines = (args?["maxLines"] as? NSNumber)?.intValue
        minLines = (args?["minLines"] as? NSNumber)?.intValue
        validationPattern = args?["validationPattern"] as? String
        errorText = args?["errorText"] as? String
        helperText = args?["helperText"] as? String
        counterText = args?["counterText"] as? String
        width = (args?["width"] as? NSNumber).map { CGFloat(truncating: $0) }
        height = (args?["height"] as? NSNumber).map { CGFloat(truncating: $0) }
        textAlign = (args?["textAlign"] as? Int) ?? 0
        tint = Self.decodeColor(from: args?["tint"])
        backgroundColor = Self.decodeColor(from: args?["backgroundColor"])
        borderColor = Self.decodeColor(from: args?["borderColor"])
        borderRadius = (args?["borderRadius"] as? NSNumber).map { CGFloat(truncating: $0) }
        iconSize = (args?["iconSize"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 20
        textInputAction = (args?["textInputAction"] as? Int) ?? 0
        glassEffectId = args?["glassEffectId"] as? String
        maxLength = (args?["maxLength"] as? NSNumber)?.intValue
        autoFocus = (args?["autoFocus"] as? Bool) ?? false
        secureTextEntry = (args?["secureTextEntry"] as? Bool) ?? false
        // Extract prefix icon data - aligned with button pattern
        let prefixIconArgs = args?["prefixIcon"] as? [String: Any]
        prefixSfSymbol = (prefixIconArgs?["sfSymbolName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        prefixIconData = Self.decodeData(from: prefixIconArgs?["iconDataPng"])
        prefixAssetIcon = Self.decodeData(from: prefixIconArgs?["assetIconPng"])
        
        // Extract suffix icon data
        let suffixIconArgs = args?["suffixIcon"] as? [String: Any]
        suffixSfSymbol = (suffixIconArgs?["sfSymbolName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        suffixIconData = Self.decodeData(from: suffixIconArgs?["iconDataPng"])
        suffixAssetIcon = Self.decodeData(from: suffixIconArgs?["assetIconPng"])
        
        // Icon colors
        prefixIconColor = Self.decodeColor(from: args?["prefixIconColor"])
        suffixIconColor = Self.decodeColor(from: args?["suffixIconColor"])
        
        let top = (args?["paddingTop"] as? NSNumber).map { CGFloat(truncating: $0) }
        let bottom = (args?["paddingBottom"] as? NSNumber).map { CGFloat(truncating: $0) }
        let left = (args?["paddingLeft"] as? NSNumber).map { CGFloat(truncating: $0) }
        let right = (args?["paddingRight"] as? NSNumber).map { CGFloat(truncating: $0) }
        if top != nil || bottom != nil || left != nil || right != nil {
            contentInsets = NSDirectionalEdgeInsets(
                top: top ?? 0, leading: left ?? 0, bottom: bottom ?? 0, trailing: right ?? 0)
        } else {
            contentInsets = nil
        }
        
        textStyle = TextFieldLabelStyle(arguments: args?["textStyle"] as? [String: Any])
        hintStyle = TextFieldLabelStyle(arguments: args?["hintStyle"] as? [String: Any])
        labelStyle = TextFieldLabelStyle(arguments: args?["labelStyle"] as? [String: Any])
        
        borderColorValue = Self.decodeColor(from: args?["borderColor"])
        borderWidth = (args?["borderWidth"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 0
        
magnifierStyle = {
    guard let styleString = args?["magnifierStyle"] as? String else { 
        // Default to glass style for iOS 17+
        return .glass
    }
    switch styleString {
    case "glass": return .glass
    case "minimal": return .minimal
    case "elevated": return .elevated
    case "compact": return .compact
    default: return .glass
    }
}()
    }
    
    public func withEnabled(_ enabled: Bool) -> LiquidGlassTextFieldConfig {
        var copy = self
        copy = LiquidGlassTextFieldConfig(arguments: [
            "text": text as Any,
            "enabled": enabled
        ])
        return copy
    }
    
    private static func decodeData(from value: Any?) -> Data? {
        if let typedData = value as? FlutterStandardTypedData { return typedData.data }
        if let data = value as? Data { return data }
        return nil
    }
    
    private static func decodeColor(from value: Any?) -> UIColor? {
        guard let numericValue = value as? NSNumber else { return nil }
        let argb = UInt32(bitPattern: Int32(truncatingIfNeeded: numericValue.intValue))
        let alpha = CGFloat((argb >> 24) & 0xFF) / 255.0
        let red = CGFloat((argb >> 16) & 0xFF) / 255.0
        let green = CGFloat((argb >> 8) & 0xFF) / 255.0
        let blue = CGFloat(argb & 0xFF) / 255.0
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    // MARK: - Icon Resolution Methods (aligned with button)
    
    private func looksLikeSvg(_ data: Data) -> Bool {
        let header = data.prefix(2048)
        guard let headerString = String(data: header, encoding: .utf8)?.lowercased() else {
            return false
        }
        return headerString.contains("<svg")
    }
    
    private func resizedImageIfNeeded(_ image: UIImage, trimAlpha: Bool) -> UIImage {
        let targetSize = iconSize
        guard targetSize > 0, image.size.width > 0, image.size.height > 0 else { return image }
        
        let rendererSize = CGSize(width: targetSize, height: targetSize)
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = max(image.scale, UIScreen.main.scale)
        let renderer = UIGraphicsImageRenderer(size: rendererSize, format: rendererFormat)
        
        let scale = min(targetSize / image.size.width, targetSize / image.size.height)
        let drawSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let drawRect = CGRect(
            x: (targetSize - drawSize.width) / 2,
            y: (targetSize - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        return renderer.image { ctx in
            ctx.cgContext.interpolationQuality = .high
            image.draw(in: drawRect)
        }
    }
    
    private func decodeImage(from data: Data, isIconData: Bool) -> UIImage? {
        if let rasterImage = UIImage(data: data) {
            return resizedImageIfNeeded(rasterImage, trimAlpha: isIconData)
        }
        guard looksLikeSvg(data) else { return nil }
        guard let svgImage = SVGKImage(data: data),
              let image = svgImage.uiImage,
              image.size.width > 0, image.size.height > 0
        else { return nil }
        return resizedImageIfNeeded(image, trimAlpha: false)
    }
    
    private func preferredImageData(iconData: Data?, assetIcon: Data?) -> (data: Data, isIconData: Bool)? {
        if let assetIcon { return (assetIcon, false) }
        if let iconData { return (iconData, true) }
        return nil
    }
    
    public func prefixImage() -> UIImage? {
        if let (data, isIconData) = preferredImageData(iconData: prefixIconData, assetIcon: prefixAssetIcon),
           let image = decodeImage(from: data, isIconData: isIconData) {
            let templateImage = image.withRenderingMode(.alwaysTemplate)
            if let color = prefixIconColor {
                return templateImage.withTintColor(color, renderingMode: .alwaysTemplate)
            }
            return templateImage
        }
        guard let sfSymbolName = prefixSfSymbol else { return nil }
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
        let image = UIImage(systemName: sfSymbolName, withConfiguration: symbolConfiguration)
        if let color = prefixIconColor {
            return image?.withTintColor(color, renderingMode: .alwaysTemplate)
        }
        return image?.withRenderingMode(.alwaysTemplate)
    }
    
    public func suffixImage() -> UIImage? {
        if let (data, isIconData) = preferredImageData(iconData: suffixIconData, assetIcon: suffixAssetIcon),
           let image = decodeImage(from: data, isIconData: isIconData) {
            let templateImage = image.withRenderingMode(.alwaysTemplate)
            if let color = suffixIconColor {
                return templateImage.withTintColor(color, renderingMode: .alwaysTemplate)
            }
            return templateImage
        }
        guard let sfSymbolName = suffixSfSymbol else { return nil }
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
        let image = UIImage(systemName: sfSymbolName, withConfiguration: symbolConfiguration)
        if let color = suffixIconColor {
            return image?.withTintColor(color, renderingMode: .alwaysTemplate)
        }
        return image?.withRenderingMode(.alwaysTemplate)
    }
}