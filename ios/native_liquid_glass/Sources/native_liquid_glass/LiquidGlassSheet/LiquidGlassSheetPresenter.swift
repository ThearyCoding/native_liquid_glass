import Flutter
import SwiftUI
import UIKit

/// Root SwiftUI view of a native bottom sheet whose content is a Flutter widget.
struct LiquidGlassSheetView: View {
  let engine: FlutterEngine
  var onFirstFrame: (() -> Void)?

  var body: some View {
    FlutterWidgetRepresentable(engine: engine, onFirstFrame: onFirstFrame)
      .edgesIgnoringSafeArea(.all)
  }
}

/// Presents native `UISheetPresentationController` sheets whose body is a
/// Flutter widget rendered by a dedicated engine running a Dart entry point.
///
/// The `showSheet` call's `FlutterResult` is held until the sheet
/// is dismissed (by swipe, by the host, or by the sheet content itself) and is
/// completed with the dismissal result.
final class LiquidGlassSheetPresenter: NSObject,
  UIAdaptivePresentationControllerDelegate
{
  /// Channel the sheet's own Dart isolate uses to talk to its container.
  static let contentChannelName = "liquid-glass-sheet-content"

  /// How long to wait for a sheet's Dart side to report `ready` before
  /// presenting anyway (e.g. an old entry point that never reports it).
  private static let readyTimeout: TimeInterval = 1.5

  /// A prewarmed engine should answer `configure` almost immediately. If it
  /// hasn't reported `ready` by then, it's discarded and the sheet starts a
  /// fresh engine instead of waiting out [readyTimeout].
  private static let spareResponseTimeout: TimeInterval = 0.4

  /// How long a new spare engine may take to report `warm` before it is
  /// considered broken and replaced.
  private static let spareWarmTimeout: TimeInterval = 2.0

  /// Delay before starting the next spare engine, so its startup doesn't
  /// compete with the presentation animation.
  private static let respawnDelay: TimeInterval = 0.6

  /// Everything needed to build and present one sheet.
  private struct SheetOptions {
    let name: String
    let argumentsJson: String
    let detents: [[String: Any]]
    let prefersGrabberVisible: Bool
    let isModal: Bool
    let cornerRadius: CGFloat?
  }

  private final class Session {
    let options: SheetOptions
    let completion: FlutterResult
    let entrypoint: String
    let libraryURI: String?
    let createdAt = CACurrentMediaTime()
    weak var host: UIViewController?
    /// Replaced if a prewarmed engine doesn't respond.
    var engine: FlutterEngine
    var contentChannel: FlutterMethodChannel
    /// Created when the sheet is presented, with the engine in use then.
    var controller: UIViewController?
    var isPresented: Bool { controller != nil }
    /// The entry point reported `ready`, so it's safe to prewarm it again.
    var reportedReady = false

    init(
      options: SheetOptions,
      engine: FlutterEngine,
      contentChannel: FlutterMethodChannel,
      completion: @escaping FlutterResult,
      entrypoint: String,
      libraryURI: String?,
      host: UIViewController
    ) {
      self.options = options
      self.engine = engine
      self.contentChannel = contentChannel
      self.completion = completion
      self.entrypoint = entrypoint
      self.libraryURI = libraryURI
      self.host = host
    }
  }

  /// An engine started ahead of time and waiting in Dart for `configure`,
  /// so the next sheet skips engine and isolate startup.
  private final class SpareEngine {
    let engine: FlutterEngine
    let contentChannel: FlutterMethodChannel
    let entrypoint: String
    let libraryURI: String?
    /// Its Dart side is running and listening for `configure`.
    var isWarm = false

    init(engine: FlutterEngine, contentChannel: FlutterMethodChannel, entrypoint: String, libraryURI: String?) {
      self.engine = engine
      self.contentChannel = contentChannel
      self.entrypoint = entrypoint
      self.libraryURI = libraryURI
    }
  }

  /// Entry point argument telling `runLiquidGlassSheet` to wait for `configure`.
  private static let prewarmArgument = "__liquid_glass_prewarm__"

  private var sessions: [Int: Session] = [:]
  private var spare: SpareEngine?

  /// Starts a spare engine for `entrypoint` so the next sheet opens fast.
  /// A spare that never reports `warm` is replaced once.
  func prewarm(entrypoint: String, libraryURI: String?, isRetry: Bool = false) {
    if let spare {
      if spare.entrypoint == entrypoint && spare.libraryURI == libraryURI { return }
      self.spare = nil
      release(engine: spare.engine)
    }
    let engine = LiquidGlassFlutterEngineFactory.makeEngine(
      entrypoint: entrypoint,
      libraryURI: libraryURI,
      arguments: [Self.prewarmArgument]
    )
    let channel = FlutterMethodChannel(
      name: Self.contentChannelName,
      binaryMessenger: engine.binaryMessenger
    )
    let newSpare = SpareEngine(
      engine: engine,
      contentChannel: channel,
      entrypoint: entrypoint,
      libraryURI: libraryURI
    )
    let startedAt = CACurrentMediaTime()
    channel.setMethodCallHandler { [weak newSpare] call, reply in
      if call.method == "warm" {
        newSpare?.isWarm = true
        #if DEBUG
          NSLog(
            "[LiquidGlassSheet] spare engine warm after %.0f ms",
            (CACurrentMediaTime() - startedAt) * 1000)
        #endif
      }
      reply(nil)
    }
    spare = newSpare

    DispatchQueue.main.asyncAfter(deadline: .now() + Self.spareWarmTimeout) { [weak self, weak newSpare] in
      guard let self, let newSpare, self.spare === newSpare, !newSpare.isWarm else { return }
      NSLog("[LiquidGlassSheet] spare engine never became warm; replacing it")
      self.spare = nil
      self.release(engine: newSpare.engine)
      if !isRetry {
        self.prewarm(entrypoint: entrypoint, libraryURI: libraryURI, isRetry: true)
      }
    }
  }

  /// Hands out the spare engine if it matches and its Dart side is running.
  private func takeSpare(entrypoint: String, libraryURI: String?) -> SpareEngine? {
    guard let spare, spare.isWarm, spare.entrypoint == entrypoint,
      spare.libraryURI == libraryURI
    else { return nil }
    self.spare = nil
    return spare
  }

  private func makeFreshEngine(id: Int, session options: SheetOptions, entrypoint: String, libraryURI: String?)
    -> (FlutterEngine, FlutterMethodChannel)
  {
    let engine = LiquidGlassFlutterEngineFactory.makeEngine(
      entrypoint: entrypoint,
      libraryURI: libraryURI,
      arguments: [String(id), options.name, options.argumentsJson]
    )
    let channel = FlutterMethodChannel(
      name: Self.contentChannelName,
      binaryMessenger: engine.binaryMessenger
    )
    return (engine, channel)
  }

  func show(id: Int, args: [String: Any], host: UIViewController, result: @escaping FlutterResult) {
    guard sessions[id] == nil else {
      result(FlutterError(code: "DUPLICATE_ID", message: "Sheet \(id) is already shown", details: nil))
      return
    }

    let entrypoint = (args["entrypoint"] as? String) ?? "bottomSheetMain"
    let libraryURI = args["libraryUri"] as? String
    let options = SheetOptions(
      name: (args["name"] as? String) ?? "",
      argumentsJson: (args["arguments"] as? String) ?? "{}",
      detents: (args["detents"] as? [[String: Any]]) ?? [["type": "medium"], ["type": "large"]],
      prefersGrabberVisible: (args["prefersGrabberVisible"] as? Bool) ?? true,
      isModal: (args["isModal"] as? Bool) ?? false,
      cornerRadius: (args["cornerRadius"] as? NSNumber).map { CGFloat($0.doubleValue) }
    )

    let warm = takeSpare(entrypoint: entrypoint, libraryURI: libraryURI)
    let (engine, channel) =
      warm.map { ($0.engine, $0.contentChannel) }
      ?? makeFreshEngine(id: id, session: options, entrypoint: entrypoint, libraryURI: libraryURI)

    let session = Session(
      options: options,
      engine: engine,
      contentChannel: channel,
      completion: result,
      entrypoint: entrypoint,
      libraryURI: libraryURI,
      host: host
    )
    sessions[id] = session
    attachHandler(id: id, to: channel)
    log(id: id, warm != nil ? "using prewarmed engine" : "starting new engine")

    if warm != nil {
      // Messages sent before Dart listens are buffered by the engine.
      channel.invokeMethod(
        "configure",
        arguments: ["id": id, "name": options.name, "arguments": options.argumentsJson]
      )
      // A prewarmed engine that doesn't answer is replaced by a fresh one
      // rather than leaving the user waiting.
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.spareResponseTimeout) { [weak self] in
        guard let self, let session = self.sessions[id], !session.reportedReady,
          !session.isPresented, session.engine === engine
        else { return }
        NSLog("[LiquidGlassSheet] sheet %d: prewarmed engine did not respond; starting new engine", id)
        session.contentChannel.setMethodCallHandler(nil)
        self.release(engine: session.engine)
        let (fresh, freshChannel) = self.makeFreshEngine(
          id: id, session: session.options, entrypoint: entrypoint, libraryURI: libraryURI)
        session.engine = fresh
        session.contentChannel = freshChannel
        self.attachHandler(id: id, to: freshChannel)
      }
    }

    // Present once the sheet's isolate has started and built its widgets
    // (it calls `ready`), so the sheet doesn't slide up empty while the
    // engine boots. Fall back to presenting after a timeout.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.readyTimeout) { [weak self] in
      guard let self, let session = self.sessions[id], !session.isPresented else { return }
      NSLog("[LiquidGlassSheet] sheet %d did not report ready; presenting anyway", id)
      self.present(id: id)
    }
  }

  private func attachHandler(id: Int, to channel: FlutterMethodChannel) {
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self else {
        reply(nil)
        return
      }
      switch call.method {
      case "ready":
        guard let session = self.sessions[id] else { break }
        session.reportedReady = true
        self.present(id: id)
        // The entry point works: keep a spare engine ready for the next sheet.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.respawnDelay) { [weak self] in
          self?.prewarm(entrypoint: session.entrypoint, libraryURI: session.libraryURI)
        }
      case "dismiss":
        let value = (call.arguments as? [String: Any])?["result"]
        self.dismiss(id: id, value: value is NSNull ? nil : value, by: "sheet content")
      case "warm":
        break
      default:
        reply(FlutterMethodNotImplemented)
        return
      }
      reply(nil)
    }
  }

  private func makeController(for session: Session, id: Int) -> UIViewController {
    let options = session.options
    let controller = UIHostingController(
      rootView: LiquidGlassSheetView(engine: session.engine) { [weak self] in
        self?.log(id: id, "first frame")
      }
    )
    if #available(iOS 26.0, *) {
      // Clear so the system Liquid Glass sheet background is visible.
      controller.view.backgroundColor = .clear
    } else {
      controller.view.backgroundColor = .systemBackground
    }
    controller.modalPresentationStyle = .pageSheet
    controller.isModalInPresentation = options.isModal

    if #available(iOS 15.0, *), let sheet = controller.sheetPresentationController {
      sheet.detents = Self.parseDetents(options.detents)
      sheet.prefersGrabberVisible = options.prefersGrabberVisible
      if let cornerRadius = options.cornerRadius {
        sheet.preferredCornerRadius = cornerRadius
      }
    }
    controller.presentationController?.delegate = self
    return controller
  }

  private func present(id: Int) {
    guard let session = sessions[id], !session.isPresented else { return }
    // The host may itself be a sheet that is closing; present from below it.
    var host = session.host
    while let candidate = host, candidate.isBeingDismissed {
      host = candidate.presentingViewController
    }
    guard let host else {
      complete(id: id, value: nil)
      release(engine: session.engine)
      return
    }
    // A previous sheet is still animating closed: present once it's gone.
    if let closing = host.presentedViewController, closing.isBeingDismissed,
      let coordinator = closing.transitionCoordinator
    {
      coordinator.animate(alongsideTransition: nil) { [weak self] _ in
        self?.present(id: id)
      }
      return
    }
    let controller = makeController(for: session, id: id)
    session.controller = controller
    log(id: id, "ready, presenting")
    host.present(controller, animated: true)
  }

  /// Closes sheet `id` and completes its result with `value`. `source` is
  /// only used for the debug log ("host app", "sheet content", "swipe").
  func dismiss(id: Int, value: Any?, by source: String) {
    guard let session = sessions[id] else { return }
    log(id: id, "closed by \(source)")
    // Complete the caller's result right away instead of after the
    // ~300 ms dismissal animation.
    complete(id: id, value: value)
    guard let controller = session.controller else {
      // Never presented: nothing on screen to animate.
      release(engine: session.engine)
      return
    }
    controller.dismiss(animated: true) { [weak self] in
      self?.release(engine: session.engine)
    }
  }

  private func log(id: Int, _ event: String) {
    #if DEBUG
      guard let session = sessions[id] else { return }
      NSLog(
        "[LiquidGlassSheet] sheet %d %@ after %.0f ms", id, event,
        (CACurrentMediaTime() - session.createdAt) * 1000)
    #endif
  }

  // Swipe-down / tap-outside dismissal.
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard
      let id = sessions.first(where: {
        $0.value.controller === presentationController.presentedViewController
      })?.key
    else { return }
    guard let session = sessions[id] else { return }
    log(id: id, "closed by swipe")
    complete(id: id, value: nil)
    release(engine: session.engine)
  }

  private func complete(id: Int, value: Any?) {
    guard let session = sessions.removeValue(forKey: id) else { return }
    session.contentChannel.setMethodCallHandler(nil)
    session.completion(value)
    // A sheet closed quickly may have closed before the next spare engine was
    // started; start it now so the next sheet doesn't boot a new engine.
    if session.reportedReady {
      prewarm(entrypoint: session.entrypoint, libraryURI: session.libraryURI)
    }
  }

  /// Drops this presenter's hold on a finished sheet's engine.
  ///
  /// Deliberately no `destroyContext()`: the engine group spawns new engines
  /// from its existing ones, and an engine that has been destroyed but not yet
  /// deallocated makes the next spawn crash ("Spawning from an engine without
  /// a shell"). Once nothing references it, the engine deallocates, leaves the
  /// group and shuts down.
  private func release(engine: FlutterEngine) {
    NativeLiquidGlassPlugin.removePresenter(for: engine.binaryMessenger)
    #if DEBUG
      // Leak check: nothing should keep a finished sheet's engine alive.
      weak var released = engine
      for delay in [3.0, 10.0] {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          NSLog(
            released == nil
              ? "[LiquidGlassSheet] sheet engine deallocated (checked at %.0f s)"
              : "[LiquidGlassSheet] sheet engine STILL ALIVE %.0f s after release",
            delay)
        }
      }
    #endif
  }

  @available(iOS 15.0, *)
  private static func parseDetents(
    _ raw: [[String: Any]]
  ) -> [UISheetPresentationController.Detent] {
    var detents: [UISheetPresentationController.Detent] = raw.compactMap { item in
      let type = item["type"] as? String
      let value = (item["value"] as? NSNumber).map { CGFloat($0.doubleValue) }
      switch type {
      case "large":
        return .large()
      case "height":
        guard let value, #available(iOS 16.0, *) else { return .medium() }
        return .custom(identifier: .init("height-\(value)")) { _ in value }
      case "fraction":
        guard let value, #available(iOS 16.0, *) else { return .medium() }
        return .custom(identifier: .init("fraction-\(value)")) { context in
          context.maximumDetentValue * value
        }
      default:
        return .medium()
      }
    }
    if detents.isEmpty {
      detents = [.medium(), .large()]
    }
    return detents
  }
}
