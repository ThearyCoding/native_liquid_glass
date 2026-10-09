import Flutter
import SwiftUI
import UIKit

// MARK: - Data model

@available(iOS 16.0, *)
struct LiquidGlassButtonData: Identifiable {
  let id = UUID()
  let buttonConfig: LiquidGlassButtonConfig
  let onPressed: () -> Void
}

// MARK: - View model

@available(iOS 16.0, *)
class LiquidGlassButtonGroupViewModel: ObservableObject {
  @Published var buttons: [LiquidGlassButtonData] = []
  @Published var axis: Axis = .horizontal
  @Published var spacing: CGFloat = 8.0
  @Published var spacingForGlass: CGFloat = 40.0
  @Published var isRouteSuppressed: Bool = false
  @Published var isPopupRouteSuppressed: Bool = false

  func updateButtons(_ newButtons: [LiquidGlassButtonData]) {
    buttons = newButtons
  }
}

// MARK: - SwiftUI group view

@available(iOS 16.0, *)
struct LiquidGlassButtonGroupSwiftUI: View {
  @ObservedObject var viewModel: LiquidGlassButtonGroupViewModel
  /// Called with the group's natural size whenever it changes, so Flutter can
  /// size the platform view to exactly fit the buttons.
  var onContentSizeChange: ((CGSize) -> Void)?
  @Namespace private var namespace

  /// For horizontal groups with multiple buttons, use a higher effective spacing
  /// so the glass blend starts sooner and reduces gaps between icons.
  private var effectiveSpacingForGlass: CGFloat {
    if viewModel.axis == .horizontal, viewModel.buttons.count >= 2 {
      return max(viewModel.spacingForGlass, 80)
    }
    return viewModel.spacingForGlass
  }

  var body: some View {
    Group {
      if #available(iOS 26.0, *) {
        GlassEffectContainer(spacing: effectiveSpacingForGlass) { measuredStack }
      } else {
        measuredStack
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .ignoresSafeArea()
  }

  /// Lays the buttons out at their natural size, independent of the platform
  /// view's current frame, and reports that size to Flutter.
  private var measuredStack: some View {
    stack
      .fixedSize()
      .onGeometryChange(for: CGSize.self) { proxy in
        proxy.size
      } action: { size in
        onContentSizeChange?(size)
      }
  }

  @ViewBuilder
  private var stack: some View {
    if viewModel.axis == .horizontal {
      HStack(alignment: .center, spacing: viewModel.spacing) { items }
    } else {
      VStack(alignment: .center, spacing: viewModel.spacing) { items }
    }
  }

  private var items: some View {
    ForEach(Array(viewModel.buttons.enumerated()), id: \.offset) { _, button in
      LiquidGlassButtonGroupItemView(
        config: button.buttonConfig,
        onPressed: button.onPressed,
        isRouteSuppressed: viewModel.isRouteSuppressed,
        isPopupRouteSuppressed: viewModel.isPopupRouteSuppressed,
        namespace: namespace
      )
      .fixedSize()
    }
  }
}
