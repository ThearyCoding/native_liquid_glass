import SwiftUI

@available(iOS 16.0, *)
public struct LiquidGlassTextFieldView: View {
    @State public var text: String
    @State private var isFocused: Bool = false
    @State private var isSecureMode: Bool = false
    @FocusState private var focused: Bool
    @State private var textViewHeight: CGFloat = 0
    
    private let config: LiquidGlassTextFieldConfig
    private let onChanged: (String) -> Void
    private let onSubmit: (String) -> Void
    private let onEditingStart: () -> Void
    private let onEditingEnd: () -> Void
    private let onPrefixIconTap: (() -> Void)?
    private let onSuffixIconTap: (() -> Void)?
    var onSizeChanged: ((CGSize) -> Void)?
    
    public init(
        config: LiquidGlassTextFieldConfig,
        onChanged: @escaping (String) -> Void,
        onSubmit: @escaping (String) -> Void,
        onEditingStart: @escaping () -> Void,
        onEditingEnd: @escaping () -> Void,
        onPrefixIconTap: (() -> Void)? = nil,
        onSuffixIconTap: (() -> Void)? = nil,
        onSizeChanged: ((CGSize) -> Void)? = nil
    ) {
        self.config = config
        self._text = State(initialValue: config.text ?? "")
        self._isSecureMode = State(initialValue: config.secureTextEntry || config.inputType == "password")
        self.onChanged = onChanged
        self.onSubmit = onSubmit
        self.onEditingStart = onEditingStart
        self.onEditingEnd = onEditingEnd
        self.onPrefixIconTap = onPrefixIconTap
        self.onSuffixIconTap = onSuffixIconTap
        self.onSizeChanged = onSizeChanged
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = config.label {
                Text(label)
                    .font(labelFont)
                    .foregroundColor(labelColor)
                    .opacity(config.enabled ? 1 : 0.5)
            }
            
            textFieldContent
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                notifySizeChange(geometry.size)
                            }
                            .onChange(of: geometry.size) { newSize in
                                notifySizeChange(newSize)
                            }
                    }
                )
            
            if let errorText = config.errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 2)
            }
            
            if let helperText = config.helperText, !helperText.isEmpty {
                Text(helperText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            if let counterText = config.counterText {
                Text(counterText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: focused) { newValue in
            if newValue {
                onEditingStart()
            } else {
                onEditingEnd()
            }
        }
        .onChange(of: text) { newValue in
            var finalText = newValue
            if let maxLength = config.maxLength, finalText.count > maxLength {
                finalText = String(finalText.prefix(maxLength))
                text = finalText
                return
            }
            onChanged(finalText)
            // Notify size change when text changes (for multiline expansion)
            DispatchQueue.main.async {
                onSizeChanged?(.zero)
            }
        }
        .onChange(of: config.secureTextEntry) { newValue in
            isSecureMode = newValue || config.inputType == "password"
        }
        .onChange(of: config.errorText) { _ in
            DispatchQueue.main.async {
                onSizeChanged?(.zero)
            }
        }
    }
    
    private func notifySizeChange(_ size: CGSize) {
        DispatchQueue.main.async {
            onSizeChanged?(size)
        }
    }
    
    @ViewBuilder
    private var textFieldContent: some View {
        HStack(alignment: .center, spacing: 12) {
            if let prefixImage = config.prefixImage() {
                Button(action: {
                    if config.enabled {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        onPrefixIconTap?()
                    }
                }) {
                    Image(uiImage: prefixImage)
                        .renderingMode(.template)
                        .foregroundColor(prefixIconColor)
                        .frame(width: config.iconSize, height: config.iconSize)
                }
                .buttonStyle(TappableIconButtonStyle())
                .disabled(!config.enabled)
            }
            
            Group {
                if isSecureMode {
                    SecureField(config.hint ?? "", text: $text)
                        .focused($focused)
                        .disabled(!config.enabled || config.readOnly)
                        .foregroundColor(textColor)
                        .font(textFont)
                        .multilineTextAlignment(textAlignment)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onSubmit { onSubmit(text) }
                        .submitLabel(submitLabel)
                } else if isMultiline {
                    AutoExpandingTextEditor(
                        text: $text,
                        font: uiFont,
                        minHeight: textEditorMinHeight,
                        maxHeight: textEditorMaxHeight,
                        onHeightChange: { newHeight in
                            DispatchQueue.main.async {
                                onSizeChanged?(.zero)
                            }
                        }
                    )
                    .focused($focused)
                    .disabled(!config.enabled || config.readOnly)
                    .foregroundColor(textColor)
                    .onSubmit { onSubmit(text) }
                    .submitLabel(submitLabel)
                } else {
                    TextField(config.hint ?? "", text: $text)
                        .focused($focused)
                        .disabled(!config.enabled || config.readOnly)
                        .foregroundColor(textColor)
                        .font(textFont)
                        .multilineTextAlignment(textAlignment)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onSubmit { onSubmit(text) }
                        .submitLabel(submitLabel)
                }
            }
            .frame(maxWidth: .infinity)
            
            if let suffixImage = config.suffixImage() {
                Button(action: {
                    if config.enabled {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        onSuffixIconTap?()
                    }
                }) {
                    Image(uiImage: suffixImage)
                        .renderingMode(.template)
                        .foregroundColor(suffixIconColor)
                        .frame(width: config.iconSize, height: config.iconSize)
                }
                .buttonStyle(TappableIconButtonStyle())
                .disabled(!config.enabled)
            }
        }
        .padding(contentPadding)
        .background(backgroundColor)
        .clipShape(textFieldShape)
        .overlay(
            textFieldShape
                .stroke(borderColor, lineWidth: borderWidth)
        )
    }
    
    // MARK: - Computed Properties
    
    private var isMultiline: Bool {
        (config.maxLines ?? 1) > 1 || config.inputType == "multiline"
    }
    
    private var textEditorMinHeight: CGFloat {
        if let minLines = config.minLines, minLines > 1 {
            return CGFloat(minLines) * 24
        }
        return 80
    }
    
    private var textEditorMaxHeight: CGFloat {
        if let maxLines = config.maxLines, maxLines > 1 {
            return CGFloat(maxLines) * 24
        }
        return 200
    }
    
    private var uiFont: UIFont {
        if let style = config.textStyle, let font = style.resolvedFont() {
            return font
        }
        return .systemFont(ofSize: 17)
    }
    
    // MARK: - Styling Properties
    
    private var prefixIconColor: Color {
        if let color = config.prefixIconColor { return Color(uiColor: color) }
        if let tint = config.tint { return Color(uiColor: tint) }
        return placeholderColor
    }
    
    private var suffixIconColor: Color {
        if let color = config.suffixIconColor { return Color(uiColor: color) }
        if let tint = config.tint { return Color(uiColor: tint) }
        return placeholderColor
    }
    
    private var textFieldShape: some Shape {
        if config.style == "rounded" {
            return AnyShape(RoundedRectangle(cornerRadius: config.borderRadius ?? 12))
        } else if config.style == "underlined" {
            return AnyShape(Rectangle())
        }
        return AnyShape(RoundedRectangle(cornerRadius: config.borderRadius ?? 8))
    }
    
    private var textAlignment: TextAlignment {
        switch config.textAlign {
        case 1: return .center
        case 2: return .trailing
        default: return .leading
        }
    }
    
    private var submitLabel: SubmitLabel {
        switch config.textInputAction {
        case 1: return .next
        case 2: return .search
        case 3: return .send
        case 4: return .continue
        case 5: return .join
        case 6: return .route
        default: return .done
        }
    }
    
    private var textColor: Color {
        if !config.enabled { return .secondary.opacity(0.5) }
        if let color = config.textStyle?.color { return Color(uiColor: color) }
        return .primary
    }
    
    private var placeholderColor: Color {
        if let color = config.hintStyle?.color { return Color(uiColor: color) }
        return .secondary.opacity(0.6)
    }
    
    private var labelColor: Color {
        if let color = config.labelStyle?.color { return Color(uiColor: color) }
        if let tint = config.tint { return Color(uiColor: tint) }
        return .secondary
    }
    
    private var textFont: Font? {
        if let style = config.textStyle, let uiFont = style.resolvedFont() {
            return Font(uiFont as CTFont)
        }
        return nil
    }
    
    private var labelFont: Font {
        if let style = config.labelStyle, let fontSize = style.fontSize {
            return .system(size: fontSize, weight: .medium)
        }
        return .caption
    }
    
    private var backgroundColor: Color {
        if let bg = config.backgroundColor { return Color(uiColor: bg) }
        if config.style == "rounded" { return Color(.systemGray6) }
        if config.style == "glass" { return Color(.systemBackground).opacity(0.8) }
        return .clear
    }
    
    private var borderColor: Color {
        if config.errorText != nil { return .red }
        if let bc = config.borderColorValue { return Color(uiColor: bc) }
        if focused, let tint = config.tint { return Color(uiColor: tint) }
        return .secondary.opacity(0.3)
    }
    
    private var borderWidth: CGFloat {
        if config.errorText != nil { return 1.5 }
        if focused { return 1.5 }
        if config.style == "underlined" { return 1 }
        return config.borderWidth > 0 ? config.borderWidth : 0.5
    }
    
    private var contentPadding: EdgeInsets {
        if let insets = config.contentInsets {
            return EdgeInsets(
                top: insets.top,
                leading: insets.leading,
                bottom: insets.bottom,
                trailing: insets.trailing
            )
        }
        let vertical: CGFloat = isMultiline ? 12 : 12
        let horizontal: CGFloat = 16
        return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
}

// MARK: - Auto Expanding TextEditor

@available(iOS 16.0, *)
struct AutoExpandingTextEditor: UIViewRepresentable {
    @Binding var text: String
    let font: UIFont
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let onHeightChange: (CGFloat) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = true
        textView.font = font
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        
        // Calculate content height
        let fixedWidth = uiView.frame.width
        let newSize = uiView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        let newHeight = min(max(newSize.height, minHeight), maxHeight)
        
        if uiView.frame.height != newHeight {
            DispatchQueue.main.async {
                onHeightChange(newHeight)
            }
        }
        
        uiView.isScrollEnabled = newSize.height > maxHeight
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoExpandingTextEditor
        
        init(_ parent: AutoExpandingTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

@available(iOS 16.0, *)
struct TappableIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

@available(iOS 16.0, *)
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}