import SwiftUI

@available(iOS 16.0, *)
public struct LiquidGlassTextFieldView: View {
    @State public var text: String
    @State private var isFocused: Bool = false
    @State private var isSecureMode: Bool = false
    @FocusState private var focused: Bool
    @State private var textViewHeight: CGFloat = 0
    /// Text applied from Flutter; its `onChange` must not be echoed back to
    /// Flutter as if the user typed it.
    @State private var appliedExternalText: String?
    /// OTP boxes: available row width (to fit the boxes) and shake offset.
    @State private var otpRowWidth: CGFloat = 0
    @State private var otpShakeOffset: CGFloat = 0
    
    private let config: LiquidGlassTextFieldConfig
    @ObservedObject private var focusCoordinator: TextFieldFocusCoordinator
    private let onChanged: (String) -> Void
    private let onSubmit: (String) -> Void
    private let onEditingStart: () -> Void
    private let onEditingEnd: () -> Void
    private let onPrefixIconTap: (() -> Void)?
    private let onSuffixIconTap: (() -> Void)?
    /// Natural size of the whole stack, called synchronously when measured.
    var onSizeChanged: ((CGSize) -> Void)?

    public init(
        config: LiquidGlassTextFieldConfig,
        focusCoordinator: TextFieldFocusCoordinator,
        onChanged: @escaping (String) -> Void,
        onSubmit: @escaping (String) -> Void,
        onEditingStart: @escaping () -> Void,
        onEditingEnd: @escaping () -> Void,
        onPrefixIconTap: (() -> Void)? = nil,
        onSuffixIconTap: (() -> Void)? = nil,
        onSizeChanged: ((CGSize) -> Void)? = nil
    ) {
        self.config = config
        self.focusCoordinator = focusCoordinator
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
    
    /// Must match `_validationAnimationDuration` / `Curves.easeOut` in
    /// `liquid_glass_text_field.dart`, which animates the Flutter box to the
    /// same height over the same time, so both sides move together.
    private static let validationAnimation = Animation.easeOut(duration: 0.2)

    /// Rows below the field fade and slide in/out with the box resize.
    private static let messageTransition = AnyTransition.opacity.combined(with: .move(edge: .top))

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = config.label {
                Text(label)
                    .font(labelFont)
                    .foregroundColor(labelColor)
                    .opacity(config.enabled ? 1 : 0.5)
            }

            if isOtpBoxes {
                otpBoxesContent
            } else {
                textFieldContent
            }

            if let errorText = config.errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 2)
                    .transition(Self.messageTransition)
            }

            if let helperText = config.helperText, !helperText.isEmpty {
                Text(helperText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                    .transition(Self.messageTransition)
            }

            if let counterText = config.counterText {
                Text(counterText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 2)
                    .transition(Self.messageTransition)
            }
        }
        .animation(Self.validationAnimation, value: config.errorText)
        .animation(Self.validationAnimation, value: config.helperText)
        .animation(Self.validationAnimation, value: config.counterText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            // Measures the full stack (label + field + error/helper/counter),
            // not just the field box, so Flutter's SizedBox reserves enough
            // height. `clipsToBounds` is false on the host container, so an
            // undersized box lets the label/helper text bleed into whatever
            // is laid out above/below this field in Flutter.
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
        // Pinned to the top of the platform view: while Flutter's box
        // animates to the new height, the field stays put and only the rows
        // below it change, instead of the whole stack sliding to stay centered.
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: focused) { newValue in
            if newValue {
                onEditingStart()
            } else {
                onEditingEnd()
            }
        }
        .onChange(of: focusCoordinator.externalText.token) { _ in
            let newText = focusCoordinator.externalText.value
            if newText != text {
                appliedExternalText = newText
                text = newText
            }
        }
        .onChange(of: text) { newValue in
            if newValue == appliedExternalText {
                appliedExternalText = nil
                return
            }
            var finalText = newValue
            // Codes are digits only; drop anything else (e.g. from a paste).
            if isOtp {
                let digits = finalText.filter(\.isNumber)
                if digits != finalText {
                    text = digits
                    return
                }
            }
            if let maxLength = config.maxLength, finalText.count > maxLength {
                finalText = String(finalText.prefix(maxLength))
                text = finalText
                return
            }
            onChanged(finalText)
        }
        .onChange(of: config.secureTextEntry) { newValue in
            isSecureMode = newValue || config.inputType == "password"
        }
        .onChange(of: focusCoordinator.focusToken) { _ in
            focused = true
        }
        .onChange(of: focusCoordinator.blurToken) { _ in
            focused = false
        }
    }
    
    /// Every height change (error row, multiline growth, label) changes the
    /// stack's geometry, so this is the only place sizes are reported from.
    private func notifySizeChange(_ size: CGSize) {
        // Synchronous, so the receiver can tag the measurement with the
        // config revision in force right now. (This action can run with the
        // previous body's values, so `config` here may already be stale.)
        onSizeChanged?(size)
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
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled(isOtp || !config.autocorrect || !config.enableSuggestions)
                        .keyboardType(nativeKeyboardType)
                        .textContentType(nativeContentType)
                        .onSubmit { onSubmit(text) }
                        .submitLabel(submitLabel)
                } else if isMultiline {
                    AutoExpandingTextEditor(
                        text: $text,
                        font: uiFont,
                        minHeight: textEditorMinHeight,
                        maxHeight: textEditorMaxHeight,
                        autocapitalizationType: legacyAutocapitalization,
                        autocorrect: config.autocorrect && config.enableSuggestions,
                        onHeightChange: { _ in
                            // The stack's geometry change reports the new size.
                        }
                    )
                    .focused($focused)
                    .disabled(!config.enabled || config.readOnly)
                    .foregroundColor(textColor)
                    .onSubmit { onSubmit(text) }
                    .submitLabel(submitLabel)
                    .overlay(alignment: .topLeading) {
                        // UITextView has no placeholder of its own.
                        if text.isEmpty, let hint = config.hint, !hint.isEmpty {
                            Text(hint)
                                .font(Font(uiFont as CTFont))
                                .foregroundColor(placeholderColor)
                                .allowsHitTesting(false)
                        }
                    }
                } else {
                    TextField(config.hint ?? "", text: $text)
                        .focused($focused)
                        .disabled(!config.enabled || config.readOnly)
                        .foregroundColor(textColor)
                        .font(textFont)
                        .multilineTextAlignment(textAlignment)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled(isOtp || !config.autocorrect || !config.enableSuggestions)
                        .keyboardType(nativeKeyboardType)
                        .textContentType(nativeContentType)
                        .onSubmit { onSubmit(text) }
                        .submitLabel(submitLabel)
                }
            }
            .tint(cursorTint)
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
    
    // MARK: - OTP boxes

    /// One glass box per digit instead of the field box. A hidden text field
    /// (bound to the same `text`) owns the keyboard, paste and one-time-code
    /// autofill, so filling it fills every box.
    private var isOtpBoxes: Bool { isOtp && config.otpStyle == "boxes" }

    private var otpLength: Int { max(config.maxLength ?? 6, 1) }
    private static let otpBoxSpacing: CGFloat = 8
    /// Boxes stop growing taller past this, so they stay sensible on wide
    /// screens; they keep stretching in width to fill the row.
    private static let otpMaxBoxHeight: CGFloat = 56

    /// The boxes fill the field's width edge to edge with equal spacing, so
    /// the row is always centered in the field.
    private var otpBoxWidth: CGFloat {
        let n = CGFloat(otpLength)
        let width = otpRowWidth > 0 ? otpRowWidth : n * 50 + (n - 1) * Self.otpBoxSpacing
        return max(28, (width - (n - 1) * Self.otpBoxSpacing) / n)
    }

    private var otpBoxHeight: CGFloat { min(otpBoxWidth, Self.otpMaxBoxHeight) }

    private var otpActiveIndex: Int { min(text.count, otpLength - 1) }

    @ViewBuilder
    private var otpBoxesContent: some View {
        ZStack(alignment: .leading) {
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .autocorrectionDisabled()
                .focused($focused)
                .disabled(!config.enabled || config.readOnly)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(width: 1, height: 1)
                .opacity(0.02)
                .accessibilityHidden(true)

            otpBoxRow
                .offset(x: otpShakeOffset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if config.enabled && !config.readOnly { focused = true }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(config.label ?? "Verification code")
                .accessibilityValue("\(text.count) of \(otpLength) digits entered")
                .accessibilityAddTraits(.isButton)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { otpRowWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { otpRowWidth = $0 }
            }
        )
        .onChange(of: config.errorText) { newValue in
            if let newValue, !newValue.isEmpty { shakeOtpBoxes() }
        }
    }

    @ViewBuilder
    private var otpBoxRow: some View {
        let row = HStack(spacing: Self.otpBoxSpacing) {
            ForEach(0..<otpLength, id: \.self) { index in
                otpBox(index)
            }
        }
        if #available(iOS 26.0, *), config.style == "glass" {
            GlassEffectContainer(spacing: Self.otpBoxSpacing) { row }
        } else {
            row
        }
    }

    @ViewBuilder
    private func otpBox(_ index: Int) -> some View {
        let digits = Array(text)
        let digit = index < digits.count ? String(digits[index]) : nil
        let isActive = focused && index == otpActiveIndex
        let hasError = !(config.errorText ?? "").isEmpty
        let shape = RoundedRectangle(cornerRadius: config.borderRadius ?? 14, style: .continuous)
        let height = otpBoxHeight

        let accent: Color = hasError ? .red : (isActive ? otpActiveColor : .clear)
        let emphasized = isActive || hasError

        // Border, digit and caret are the box's own content: inside a glass
        // container, overlays and siblings are drawn under the glass material.
        let content = ZStack {
            otpBoxBorder(shape: shape, accent: accent, emphasized: emphasized)
            if let digit {
                Text(isSecureMode ? "●" : digit)
                    .font(.system(size: height * 0.45, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            } else if isActive {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(otpActiveColor)
                        .frame(width: 2, height: height * 0.45)
                        .opacity(Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? 1 : 0)
                }
            }
        }
        .frame(width: otpBoxWidth, height: height)

        // Each box follows the field's `style`, like the regular field box.
        Group {
            switch config.style {
            case "glass":
                if #available(iOS 26.0, *) {
                    content.glassEffect(otpGlass, in: shape)
                } else {
                    // Plain system fill before iOS 26.
                    content.background(Color(.systemGray6), in: shape)
                }
            case "rounded":
                content.background(backgroundColor, in: shape)
            default:  // "plain", "underlined": no fill
                content
            }
        }
        .scaleEffect(isActive ? 1.06 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: digit)
    }

    /// Per style: an underline ("underlined"), an always-visible outline
    /// ("plain"), or an outline only when active / in error ("glass",
    /// "rounded").
    @ViewBuilder
    private func otpBoxBorder(shape: RoundedRectangle, accent: Color, emphasized: Bool) -> some View {
        switch config.style {
        case "underlined":
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(emphasized ? accent : Color.secondary.opacity(0.4))
                    .frame(height: emphasized ? 2 : 1)
            }
        case "plain":
            shape.strokeBorder(
                emphasized ? accent : Color.secondary.opacity(0.3),
                lineWidth: emphasized ? 2 : 1)
        default:
            shape.strokeBorder(accent, lineWidth: emphasized ? 2 : 0)
        }
    }

    @available(iOS 26.0, *)
    private var otpGlass: Glass {
        var glass = Glass.regular.interactive()
        if let tint = config.tint { glass = glass.tint(Color(uiColor: tint).opacity(0.25)) }
        return glass
    }

    private var otpActiveColor: Color { cursorTint ?? .accentColor }

    /// Short horizontal shake with an error haptic when an error appears.
    private func shakeOtpBoxes() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        withAnimation(.linear(duration: 0.05).repeatCount(5, autoreverses: true)) {
            otpShakeOffset = 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { otpShakeOffset = 0 }
        }
    }

    // MARK: - Computed Properties
    
    private var isMultiline: Bool {
        (config.maxLines ?? 1) > 1 || config.inputType == "multiline"
    }
    
    private var textEditorMinHeight: CGFloat {
        if let minLines = config.minLines, minLines > 1 {
            return ceil(CGFloat(minLines) * uiFont.lineHeight)
        }
        return ceil(uiFont.lineHeight)
    }
    
    private var textEditorMaxHeight: CGFloat {
        if let maxLines = config.maxLines, maxLines > 1 {
            return ceil(CGFloat(maxLines) * uiFont.lineHeight)
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
        case "go": return .go
        case "search": return .search
        case "send": return .send
        case "next": return .next
        case "continueAction": return .continue
        case "join": return .join
        case "route": return .route
        default: return .done
        }
    }

    private var autocapitalization: TextInputAutocapitalization {
        switch config.textCapitalization {
        case "words": return .words
        case "sentences": return .sentences
        case "characters": return .characters
        default: return .never
        }
    }

    private var cursorTint: Color? {
        if let cursorColor = config.cursorColor { return Color(uiColor: cursorColor) }
        if let tint = config.tint { return Color(uiColor: tint) }
        return nil
    }

    private var legacyAutocapitalization: UITextAutocapitalizationType {
        switch config.textCapitalization {
        case "words": return .words
        case "sentences": return .sentences
        case "characters": return .allCharacters
        default: return .none
        }
    }

    /// One-time code entry: number pad, digits only, and iOS offers the code
    /// from Messages / Mail above the keyboard (`.oneTimeCode`).
    private var isOtp: Bool { config.inputType == "otp" }

    private var nativeContentType: UITextContentType? {
        isOtp ? .oneTimeCode : nil
    }

    private var nativeKeyboardType: UIKeyboardType {
        switch config.inputType {
        case "email": return .emailAddress
        case "number", "otp": return .numberPad
        case "phone": return .phonePad
        case "url": return .URL
        default: return .default
        }
    }

    private var textColor: Color {
        if !config.enabled { return .secondary.opacity(0.5) }
        if let color = config.foregroundColor { return Color(uiColor: color) }
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
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var autocorrect: Bool = true
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
        uiView.autocapitalizationType = autocapitalizationType
        uiView.autocorrectionType = autocorrect ? .yes : .no
        uiView.spellCheckingType = autocorrect ? .yes : .no
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

    /// Grows with the text between `minHeight` and `maxHeight` (minLines /
    /// maxLines), then scrolls.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0, width.isFinite else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: min(max(ceil(fitting.height), minHeight), maxHeight))
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