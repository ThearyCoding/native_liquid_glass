import UIKit
import SwiftUI

/// Magnifier style types for text selection
@objc public enum MagnifierStyle: Int {
    case `default` = 0      // Standard iOS magnifier
    case glass = 1          // Liquid Glass style (enhanced version)
    case minimal = 2        // Minimal style with less visual weight
    case elevated = 3       // Elevated with shadow
    case compact = 4        // Compact size for small text
}

/// Custom magnifier view for Liquid Glass text fields
@available(iOS 13.0, *)
public class LiquidGlassMagnifierView: UIView {
    
    private let glassLayer = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let contentView = UIView()
    private let textLabel = UILabel()
    
    private var style: MagnifierStyle = .glass
    private weak var textField: UITextField?
    private var timer: Timer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        addSubview(glassLayer)
        glassLayer.contentView.addSubview(contentView)
        contentView.addSubview(textLabel)
        
        textLabel.numberOfLines = 0
        textLabel.textAlignment = .center
        
        alpha = 0
        isHidden = true
        
        // Add tap gesture to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        addGestureRecognizer(tapGesture)
    }
    
    public func configure(style: MagnifierStyle, textField: UITextField) {
        self.style = style
        self.textField = textField
        applyStyle(style)
    }
    
    public func show(at point: CGPoint, withText text: String) {
        updateText(text)
        
        isHidden = false
        alpha = 1
        center = CGPoint(x: point.x, y: point.y - 80)
        
        // Add animation
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            self.transform = .identity
        }
        
        // Auto-dismiss after 1.5 seconds
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }
    
    @objc public func dismiss() {
        timer?.invalidate()
        timer = nil
        
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { _ in
            self.isHidden = true
            self.removeFromSuperview()
        }
    }
    
    private func applyStyle(_ style: MagnifierStyle) {
        let size: CGFloat
        
        switch style {
        case .glass:
            size = 140
            
            glassLayer.effect = UIBlurEffect(style: .systemUltraThinMaterial)
            glassLayer.layer.cornerRadius = size / 2
            glassLayer.layer.borderWidth = 0.5
            glassLayer.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            glassLayer.layer.shadowColor = UIColor.black.cgColor
            glassLayer.layer.shadowRadius = 25
            glassLayer.layer.shadowOpacity = 0.4
            glassLayer.layer.shadowOffset = .zero
            
            let shineLayer = CAGradientLayer()
            shineLayer.colors = [
                UIColor.white.withAlphaComponent(0.5).cgColor,
                UIColor.clear.cgColor,
                UIColor.white.withAlphaComponent(0.15).cgColor
            ]
            shineLayer.locations = [0, 0.5, 1]
            shineLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
            glassLayer.layer.addSublayer(shineLayer)
            
            layer.shadowRadius = 35
            layer.shadowOpacity = 0.6
            textLabel.font = .monospacedDigitSystemFont(ofSize: 24, weight: .medium)
            
        case .minimal:
            size = 110
            
            glassLayer.effect = UIBlurEffect(style: .systemThinMaterial)
            glassLayer.layer.cornerRadius = size / 2
            glassLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            textLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
            
        case .elevated:
            size = 120
            
            glassLayer.effect = UIBlurEffect(style: .systemMaterial)
            glassLayer.layer.cornerRadius = size / 2
            glassLayer.layer.shadowColor = UIColor.black.cgColor
            glassLayer.layer.shadowRadius = 30
            glassLayer.layer.shadowOpacity = 0.5
            glassLayer.layer.shadowOffset = CGSize(width: 0, height: 8)
            textLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .medium)
            
        case .compact:
            size = 90
            
            glassLayer.effect = UIBlurEffect(style: .systemUltraThinMaterial)
            glassLayer.layer.cornerRadius = size / 2
            textLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
            
        case .default:
            size = 120
            
            glassLayer.effect = UIBlurEffect(style: .systemMaterial)
            glassLayer.layer.cornerRadius = size / 2
            textLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        }
        
        frame.size = CGSize(width: size, height: size)
        glassLayer.frame = bounds
        glassLayer.layer.cornerCurve = .continuous
        glassLayer.clipsToBounds = true
        
        contentView.frame = bounds.insetBy(dx: 15, dy: 15)
        textLabel.frame = contentView.bounds
        textLabel.textColor = .label
    }
    
    private func updateText(_ text: String) {
        var displayText = text
        if displayText.isEmpty {
            displayText = textField?.text ?? ""
        }
        if displayText.count > 30 {
            displayText = String(displayText.prefix(30)) + "..."
        }
        textLabel.text = displayText
    }
}

// MARK: - UITextField Extension for Custom Magnifier

extension UITextField {
    
    private static var magnifierStyleKey: UInt8 = 0
    private static var customMagnifierKey: UInt8 = 0
    private static var longPressKey: UInt8 = 0
    
    public var magnifierStyle: MagnifierStyle {
        get {
            return (objc_getAssociatedObject(self, &UITextField.magnifierStyleKey) as? MagnifierStyle) ?? .glass
        }
        set {
            objc_setAssociatedObject(self, &UITextField.magnifierStyleKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setupCustomMagnifier()
        }
    }
    
    private func setupCustomMagnifier() {
        // Remove existing custom gesture if any
        if let existingGesture = objc_getAssociatedObject(self, &UITextField.longPressKey) as? UILongPressGestureRecognizer {
            removeGestureRecognizer(existingGesture)
        }
        
        // Create custom long press gesture
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleCustomLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)
        objc_setAssociatedObject(self, &UITextField.longPressKey, longPressGesture, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    @objc private func handleCustomLongPress(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: self)
        
        // Only show loupe when gesture is over text area
        guard point.y > 0 && point.y < bounds.height && point.x > 0 && point.x < bounds.width else { return }
        
        switch gesture.state {
        case .began:
            showCustomMagnifier(at: point)
            
        case .changed:
            updateCustomMagnifierPosition(at: point)
            
        case .ended, .cancelled:
            dismissCustomMagnifier()
            
        default:
            break
        }
    }
    
    private func showCustomMagnifier(at point: CGPoint) {
        guard let window = window else { return }
        
        // Dismiss existing magnifier if any
        dismissCustomMagnifier()
        
        // Get text to display
        var displayText = text ?? ""
        if let selectedRange = selectedTextRange,
           let selectedText = text(in: selectedRange),
           !selectedText.isEmpty {
            displayText = selectedText
        }
        
        // Create custom magnifier view
        let magnifier = LiquidGlassMagnifierView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        magnifier.configure(style: magnifierStyle, textField: self)
        magnifier.show(at: point, withText: displayText)
        
        window.addSubview(magnifier)
        
        // Store reference
        objc_setAssociatedObject(self, &UITextField.customMagnifierKey, magnifier, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Trigger haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func updateCustomMagnifierPosition(at point: CGPoint) {
        guard let magnifier = objc_getAssociatedObject(self, &UITextField.customMagnifierKey) as? LiquidGlassMagnifierView else { return }
        
        // Update position
        magnifier.center = CGPoint(x: point.x, y: point.y - 80)
        
        // Update text if selection changed
        var displayText = text ?? ""
        if let selectedRange = selectedTextRange,
           let selectedText = text(in: selectedRange),
           !selectedText.isEmpty {
            displayText = selectedText
        }
        
        // Use reflection to update text (simple approach - recreate)
        magnifier.dismiss()
        
        guard let window = window else { return }
        let newMagnifier = LiquidGlassMagnifierView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        newMagnifier.configure(style: magnifierStyle, textField: self)
        newMagnifier.show(at: point, withText: displayText)
        window.addSubview(newMagnifier)
        objc_setAssociatedObject(self, &UITextField.customMagnifierKey, newMagnifier, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    private func dismissCustomMagnifier() {
        guard let magnifier = objc_getAssociatedObject(self, &UITextField.customMagnifierKey) as? LiquidGlassMagnifierView else { return }
        magnifier.dismiss()
        objc_setAssociatedObject(self, &UITextField.customMagnifierKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}