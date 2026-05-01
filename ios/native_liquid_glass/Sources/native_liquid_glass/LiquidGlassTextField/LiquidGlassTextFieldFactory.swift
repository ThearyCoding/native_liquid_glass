import Flutter
import UIKit

/// Factory for creating Liquid Glass text field platform views
public class LiquidGlassTextFieldViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    
    public init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
    
    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        LiquidGlassTextFieldPlatformView(
            frame: frame,
            viewId: viewId,
            arguments: args as? [String: Any],
            messenger: messenger
        )
    }
}