import Flutter
import SwiftUI
import UIKit

/// Spawns lightweight engines that run a Dart `@pragma('vm:entry-point')`
/// function. Engines spawned from the same group share the isolate group and
/// compiled code, so every sheet after the first starts almost instantly.
public enum LiquidGlassFlutterEngineFactory {
  private static let engineGroup = FlutterEngineGroup(
    name: "liquid-glass-sheet",
    project: nil
  )

  /// Spawns an engine running `entrypoint` (defaults to the app's main library
  /// when `libraryURI` is nil) and registers plugins on it.
  public static func makeEngine(
    entrypoint: String,
    libraryURI: String? = nil,
    initialRoute: String? = nil,
    arguments: [String] = []
  ) -> FlutterEngine {
    let options = FlutterEngineGroupOptions()
    options.entrypoint = entrypoint
    options.libraryURI = libraryURI
    options.initialRoute = initialRoute
    options.entrypointArgs = arguments
    let engine = engineGroup.makeEngine(with: options)

    if let registrant = NativeLiquidGlassPlugin.flutterSheetPluginRegistrant {
      registrant(engine)
    } else if let registrar = engine.registrar(forPlugin: "NativeLiquidGlassPlugin") {
      NativeLiquidGlassPlugin.register(with: registrar)
    }
    return engine
  }
}

/// SwiftUI view that embeds a Flutter widget tree rendered by its own engine.
///
/// Either pass an already-spawned `engine` (the caller owns its lifetime), or
/// pass an `entrypoint` and the representable spawns and destroys its own.
///
/// ```swift
/// .sheet(isPresented: $show) {
///   FlutterWidgetRepresentable(entrypoint: "bottomSheetMain", arguments: ["0", "profile", "{}"])
///     .ignoresSafeArea()
///     .presentationDetents([.medium, .large])
/// }
/// ```
public struct FlutterWidgetRepresentable: UIViewControllerRepresentable {
  private let engine: FlutterEngine?
  private let entrypoint: String
  private let libraryURI: String?
  private let arguments: [String]
  private let isOpaque: Bool
  private let onFirstFrame: (() -> Void)?

  /// `onFirstFrame` is called once Flutter has rendered its first frame.
  public init(
    engine: FlutterEngine,
    isOpaque: Bool = false,
    onFirstFrame: (() -> Void)? = nil
  ) {
    self.engine = engine
    self.entrypoint = ""
    self.libraryURI = nil
    self.arguments = []
    self.isOpaque = isOpaque
    self.onFirstFrame = onFirstFrame
  }

  public init(
    entrypoint: String = "bottomSheetMain",
    libraryURI: String? = nil,
    arguments: [String] = [],
    isOpaque: Bool = false,
    onFirstFrame: (() -> Void)? = nil
  ) {
    self.engine = nil
    self.entrypoint = entrypoint
    self.libraryURI = libraryURI
    self.arguments = arguments
    self.isOpaque = isOpaque
    self.onFirstFrame = onFirstFrame
  }

  public final class Coordinator {
    fileprivate var ownedEngine: FlutterEngine?
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  public func makeUIViewController(context: Context) -> FlutterViewController {
    let resolvedEngine: FlutterEngine
    if let engine {
      resolvedEngine = engine
    } else {
      resolvedEngine = LiquidGlassFlutterEngineFactory.makeEngine(
        entrypoint: entrypoint,
        libraryURI: libraryURI,
        arguments: arguments
      )
      context.coordinator.ownedEngine = resolvedEngine
    }

    let flutterVC = FlutterViewController(engine: resolvedEngine, nibName: nil, bundle: nil)
    // Transparent so the native sheet background (Liquid Glass on iOS 26)
    // shows through wherever the Flutter content doesn't paint.
    flutterVC.isViewOpaque = isOpaque
    flutterVC.view.backgroundColor = .clear
    if let onFirstFrame {
      flutterVC.setFlutterViewDidRenderCallback(onFirstFrame)
    }
    return flutterVC
  }

  public func updateUIViewController(_ uiViewController: FlutterViewController, context: Context) {}

  public static func dismantleUIViewController(
    _ uiViewController: FlutterViewController,
    coordinator: Coordinator
  ) {
    // Dropping the last reference shuts the engine down. No `destroyContext()`:
    // a destroyed engine still alive in the engine group crashes later spawns.
    coordinator.ownedEngine = nil
  }
}
