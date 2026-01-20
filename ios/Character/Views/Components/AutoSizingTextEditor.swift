// AutoSizingTextEditor.swift
import SwiftUI

struct AutoSizingTextEditor: View {
    @Binding var text: String
    @State private var dynamicHeight: CGFloat = UIFont.preferredFont(forTextStyle: .body).lineHeight * 1.5

    var body: some View {
        ZStack(alignment: .topLeading) {
            UITextViewWrapper(text: $text, calculatedHeight: $dynamicHeight)
                .frame(minHeight: dynamicHeight, maxHeight: dynamicHeight)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))
        }
    }
}

private struct UITextViewWrapper: UIViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != self.text {
            uiView.text = self.text
        }
        UITextViewWrapper.recalculateHeight(view: uiView, result: $calculatedHeight)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, height: $calculatedHeight)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var height: Binding<CGFloat>

        init(text: Binding<String>, height: Binding<CGFloat>) {
            self.text = text
            self.height = height
        }

        func textViewDidChange(_ textView: UITextView) {
            self.text.wrappedValue = textView.text
            UITextViewWrapper.recalculateHeight(view: textView, result: height)
        }
    }

    static func recalculateHeight(view: UIView, result: Binding<CGFloat>) {
        let newSize = view.sizeThatFits(CGSize(width: view.bounds.width, height: CGFloat.greatestFiniteMagnitude))
        DispatchQueue.main.async {
            result.wrappedValue = newSize.height
        }
    }
}
