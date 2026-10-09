import SwiftUI
import UIKit

// MARK: - View Model

@available(iOS 16.0, *)
final class LiquidGlassButtonViewModel: ObservableObject {
  @Published var config: LiquidGlassButtonConfig
  @Published var isRouteSuppressed: Bool = false
  @Published var isPopupRouteSuppressed: Bool = false
  @Published var forceShow: Bool = false
  var onPressed: (() -> Void)?
  /// Called with the button's natural size whenever it changes.
  var onContentSizeChange: ((CGSize) -> Void)?
  var shouldSuppress: Bool {
    !forceShow && (isRouteSuppressed || isPopupRouteSuppressed)
  }
  init(config: LiquidGlassButtonConfig) {
    self.config = config
  }
}

// MARK: - Badge View

@available(iOS 16.0, *)
struct LiquidGlassButtonBadge: View {
  let text: String?
  var backgroundColor: Color = .red
  var textColor: Color = .white
  var size: CGFloat?

  var body: some View {
    if let text, !text.isEmpty {
      let fontSize = size ?? 12
      Text(text)
        .font(.system(size: fontSize, weight: .semibold))
        .foregroundColor(textColor)
        .padding(.horizontal, fontSize * 0.42)
        .padding(.vertical, fontSize * 0.17)
        .background(backgroundColor)
        .clipShape(Capsule())
        .frame(minWidth: fontSize * 1.67, minHeight: fontSize * 1.67)
    } else {
      let dotSize = size ?? 10
      Circle()
        .fill(backgroundColor)
        .frame(width: dotSize, height: dotSize)
    }
  }
}

// MARK: - Custom Button Style for Popup Suppression

@available(iOS 16.0, *)
struct FixedSizeButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

// MARK: - SwiftUI Root View

/// SwiftUI view for LiquidGlassButton. Uses glass effect modifiers on iOS 26+
/// and standard SwiftUI button styles as fallback on iOS 16–25.
@available(iOS 16.0, *)
struct LiquidGlassButtonRootView: View {
  @ObservedObject var viewModel: LiquidGlassButtonViewModel
  @Namespace private var namespace

  private var config: LiquidGlassButtonConfig { viewModel.config }
  
  private var isEffectivelyEnabled: Bool {
    // If forceShow is true, ignore suppression for enabled state
    if viewModel.forceShow {
      return config.enabled
    }
    return config.enabled && !viewModel.isRouteSuppressed
  }
  
  private var effectiveButtonStyle: String {
    // If forceShow is true, keep the original style
    if viewModel.forceShow {
      return config.buttonStyle
    }
    return viewModel.isPopupRouteSuppressed && !config.useLiquidGlassWhenPopupSuppressed
      ? "borderedProminent"
      : config.buttonStyle
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      if #available(iOS 26.0, *) {
        ios26Content
      } else {
        standardButtonView
      }
      if config.showBadge {
        LiquidGlassButtonBadge(
          text: config.badgeValue,
          backgroundColor: config.badgeColor.map { Color(uiColor: $0) } ?? .red,
          textColor: config.badgeTextColor.map { Color(uiColor: $0) } ?? .white,
          size: config.badgeSize
        )
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(.isButton)
    // Natural size, independent of the platform view's current frame, so
    // Flutter can size its box to exactly what is drawn.
    .fixedSize()
    .onGeometryChange(for: CGSize.self) { proxy in
      proxy.size
    } action: { size in
      viewModel.onContentSizeChange?(size)
    }
  }

  // MARK: iOS 26+ – glass effect path

  @available(iOS 26.0, *)
  @ViewBuilder
  private var ios26Content: some View {
    if isGlassStyle {
      GlassEffectContainer(spacing: 40) {
        Button(action: handlePress) {
          buttonLabel
            .padding(resolvedPadding())
            .frame(width: resolvedFrameWidth(), height: resolvedFrameHeight())
            .contentShape(resolvedShape())
            .glassEffect(resolvedGlass(), in: resolvedShape())
            .overlay { borderOverlay() }
            .applyLiquidGlassEffectModifiers(
              unionId: config.glassEffectUnionId,
              id: config.glassEffectId,
              namespace: namespace
            )
        }
        .clipShape(resolvedShape())
        .disabled(!isEffectivelyEnabled)
        .buttonStyle(LiquidGlassNoHighlightButtonStyle())
        .allowsHitTesting(config.interaction)
      }
    } else {
      standardButtonView
    }
  }

  /// Strokes the button's shape with the configured border color/width
  /// on top of the glass material. No-op when unset or zero-width.
  @ViewBuilder
  private func borderOverlay() -> some View {
    if config.borderWidth > 0, let color = config.borderColor {
      resolvedShape()
        .stroke(Color(uiColor: color), lineWidth: config.borderWidth)
        .allowsHitTesting(false)
    }
  }

  @ViewBuilder
private var standardButtonView: some View {
    let tint = resolvedTintColor()
    let currentStyle = standardButtonStyle
    let isDisabled = !isEffectivelyEnabled
    
    // Create content with exact sizing to preserve shape
    let content = buttonLabel
        .padding(resolvedPaddingForCurrentStyle(currentStyle))
        .frame(width: resolvedFrameWidth(), height: resolvedFrameHeight())
        .background(
            Group {
                if currentStyle == "borderedProminent" || currentStyle == "filled" {
                    resolvedShape()
                        .fill(backgroundColorForCurrentStyle(tint: tint, isDisabled: isDisabled))
                } else if currentStyle == "tinted" {
                    resolvedShape()
                        .fill(tint.map { $0.opacity(0.18) } ?? Color(uiColor: .tertiarySystemFill))
                } else if currentStyle == "gray" {
                    resolvedShape()
                        .fill(Color(.systemGray).opacity(isDisabled ? 0.1 : 0.2))
                } else if currentStyle == "bordered" {
                    resolvedShape()
                        .stroke(
                            isDisabled ? Color.gray.opacity(0.3) : (tint ?? Color.accentColor), 
                            lineWidth: 1
                        )
                        .background(resolvedShape().fill(Color.clear))
                } else {
                    resolvedShape()
                        .fill(Color.clear)
                }
            }
        )
        .foregroundColor(foregroundColorForCurrentStyle(tint: tint, isDisabled: isDisabled))
        .opacity(isDisabled ? 0.5 : 1.0)
    
    Button(action: handlePress) {
        content
    }
    .buttonStyle(FixedSizeButtonStyle())
    .disabled(isDisabled)
    .allowsHitTesting(config.interaction)
}
  private func backgroundColorForCurrentStyle(tint: Color?, isDisabled: Bool) -> Color {
    let baseColor: Color
    if let tint = tint {
        baseColor = tint
    } else if config.tint != nil {
        baseColor = Color(uiColor: config.tint!)
    } else if effectiveButtonStyle == "prominentGlass" || effectiveButtonStyle == "automatic" {
        // Plain stand-in for prominent glass (before iOS 26).
        baseColor = .accentColor
    } else {
        // Default to a neutral color instead of system blue
        baseColor = Color.gray
    }
    
    if isDisabled {
        return baseColor.opacity(0.3)
    }
    return baseColor
}

private func foregroundColorForCurrentStyle(tint: Color?, isDisabled: Bool) -> Color {
    let currentStyle = standardButtonStyle
    
    if currentStyle == "borderedProminent" || currentStyle == "filled" {
        // For filled styles, use white for text/icon
        if isDisabled {
            return Color.white.opacity(0.6)
        }
        return .white
    } else {
        // For bordered/plain styles, use the tint color; the plain stand-in
        // for glass ("tinted", before iOS 26) uses the primary label color.
        let color = effectiveTextColor ?? tint ?? (currentStyle == "tinted" ? Color.primary : Color.gray)
        if isDisabled {
            return color.opacity(0.4)
        }
        return color
    }
}

private func resolvedPaddingForCurrentStyle(_ style: String) -> EdgeInsets {
    if let insets = config.contentInsets {
        return EdgeInsets(
            top: insets.top,
            leading: insets.leading,
            bottom: insets.bottom,
            trailing: insets.trailing
        )
    }
    if config.iconOnly {
        return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    }
    return EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
}

  // MARK: Label content

  @ViewBuilder
  private var buttonLabel: some View {
    if config.iconOnly {
      iconView
        .foregroundColor(iconForeground)
    } else if config.imagePlacement == "trailing" {
      HStack(spacing: config.imagePadding) {
        textLabel
        iconView.foregroundColor(iconForeground)
      }
    } else if config.imagePlacement == "top" {
      VStack(spacing: config.imagePadding) {
        iconView.foregroundColor(iconForeground)
        textLabel
      }
    } else if config.imagePlacement == "bottom" {
      VStack(spacing: config.imagePadding) {
        textLabel
        iconView.foregroundColor(iconForeground)
      }
    } else {
      // "leading" (default)
      HStack(spacing: config.imagePadding) {
        iconView.foregroundColor(iconForeground)
        textLabel
      }
    }
  }

  @ViewBuilder
  private var iconView: some View {
    if config.assetIconPng != nil || config.iconDataPng != nil,
      let uiImage = config.resolvedImage()
    {
      Image(uiImage: uiImage)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: config.iconSize, height: config.iconSize)
    } else if let symbolName = config.sfSymbolName {
      Image(systemName: symbolName)
        .font(.system(size: config.iconSize, weight: .semibold))
    }
  }

  private var textLabel: some View {
    Text(config.title ?? "Button")
      .lineLimit(config.maxLines)
      .multilineTextAlignment(.leading)
      .font(resolvedFont())
      .kerning(config.labelStyle?.letterSpacing ?? 0)
      .foregroundColor(textForeground)
  }

  // MARK: Color resolution

  private var effectiveIconColor: Color? {
    // Explicit icon color always wins.
    if let c = config.iconColor { return Color(uiColor: c) }
    if config.iconOnly {
      // icon-only: labelColor > foregroundColor > tint (mirrors UIKit button.tintColor chain)
      if let c = config.labelColor { return Color(uiColor: c) }
      if let c = config.foregroundColor { return Color(uiColor: c) }
      if let c = config.tint { return Color(uiColor: c) }
      return nil
    }
    // text+icon: icon adopts the same colour as the text so both stay in sync,
    // matching UIKit's baseForegroundColor which colours both text and icon together.
    return effectiveTextColor
  }

  /// Whether the button is drawn by `standardButtonView` (always before
  /// iOS 26, and for the non-glass styles on iOS 26+).
  private var standardRendering: Bool {
    if #available(iOS 26.0, *) { return !isGlassStyle }
    return true
  }

  /// Unset label colors fall back to the style's default color in the
  /// standard rendering (e.g. white on `borderedProminent`). `nil` would
  /// reset the color to primary and override that default.
  private var textForeground: Color? {
    if let c = effectiveTextColor { return c }
    guard standardRendering else { return nil }
    return foregroundColorForCurrentStyle(tint: resolvedTintColor(), isDisabled: !isEffectivelyEnabled)
  }

  private var iconForeground: Color? {
    if let c = effectiveIconColor { return c }
    guard standardRendering else { return nil }
    return foregroundColorForCurrentStyle(tint: resolvedTintColor(), isDisabled: !isEffectivelyEnabled)
  }

  private var effectiveTextColor: Color? {
    let isBackgroundTintStyle = ["filled", "borderedProminent", "prominentGlass"].contains(
      effectiveButtonStyle)
    if isBackgroundTintStyle {
      if let c = config.labelColor { return Color(uiColor: c) }
      if let c = config.foregroundColor { return Color(uiColor: c) }
      return nil
    }
    if let c = config.labelColor { return Color(uiColor: c) }
    if let c = config.foregroundColor { return Color(uiColor: c) }
    if let c = config.tint { return Color(uiColor: c) }
    return nil
  }

  private func resolvedTintColor() -> Color? {
    if let c = config.tint { return Color(uiColor: c) }
    if let c = config.foregroundColor { return Color(uiColor: c) }
    return nil
  }

  // MARK: Font resolution

  private func resolvedFont() -> Font? {
    guard let style = config.labelStyle else { return nil }
    let size = style.fontSize ?? 17.0
    if let family = style.fontFamily {
      return .custom(family, size: size)
    }
    let weight = style.fontWeight.map { mapToSwiftUIWeight($0) } ?? .regular
    return .system(size: size, weight: weight)
  }

  private func mapToSwiftUIWeight(_ uiWeight: UIFont.Weight) -> Font.Weight {
    switch uiWeight {
    case .ultraLight: return .ultraLight
    case .thin: return .thin
    case .light: return .light
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    case .heavy: return .heavy
    case .black: return .black
    default: return .regular
    }
  }

  // MARK: Shape, sizing, padding

  private func resolvedShape() -> AnyShape {
    // CRITICAL FIX: Always preserve circular shape for icon-only buttons
    if config.iconOnly {
      return AnyShape(Circle())
    }
    if let r = config.borderRadius {
      return AnyShape(RoundedRectangle(cornerRadius: r))
    }
    return AnyShape(Capsule())
  }

  private func resolvedFrameWidth() -> CGFloat? {
    if config.iconOnly {
      return config.height > 0 ? config.height : config.width
    }
    return config.width
  }

  private func resolvedFrameHeight() -> CGFloat? {
    if config.iconOnly {
      return config.height > 0 ? config.height : nil
    }
    if config.fitsContentHeight { return nil }
    return config.height > 0 ? config.height : nil
  }

  private func resolvedPadding() -> EdgeInsets {
    if let insets = config.contentInsets {
      return EdgeInsets(
        top: insets.top,
        leading: insets.leading,
        bottom: insets.bottom,
        trailing: insets.trailing
      )
    }
    if config.iconOnly {
      return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    }
    return EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
  }

  // MARK: Glass effect

  @available(iOS 26.0, *)
  private func resolvedGlass() -> Glass {
    let isProminent =
      effectiveButtonStyle == "prominentGlass" || effectiveButtonStyle == "automatic"

    var glass = Glass.regular
    if config.interactive {
      glass = glass.interactive()
    }
    if let tint = config.tint {
      glass = glass.tint(Color(uiColor: tint))
    } else if isProminent {
      glass = glass.tint(Color.accentColor.opacity(0.25))
    }
    return glass
  }

  // MARK: Helpers

  /// The style drawn by [standardButtonView]. Without Liquid Glass
  /// (before iOS 26) the glass styles use their plain system equivalents:
  /// `glass` → `tinted`, `prominentGlass` / `automatic` (prominent glass on
  /// iOS 26) → `borderedProminent`.
  private var standardButtonStyle: String {
    switch effectiveButtonStyle {
    case "glass": return "tinted"
    case "prominentGlass", "automatic": return "borderedProminent"
    default: return effectiveButtonStyle
    }
  }

  private var isGlassStyle: Bool {
    // If forceShow is true, always use the configured style
    if viewModel.forceShow {
      return config.buttonStyle == "glass" || 
             config.buttonStyle == "prominentGlass" ||
             config.buttonStyle == "automatic"
    }
    return effectiveButtonStyle == "glass" || 
           effectiveButtonStyle == "prominentGlass" ||
           effectiveButtonStyle == "automatic"
  }

  private var accessibilityLabel: String {
    config.title ?? config.sfSymbolName ?? "Button"
  }

  private func handlePress() {
    guard config.enabled && !viewModel.isRouteSuppressed else { return }
    viewModel.onPressed?()
  }
}