import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    @Environment(\.dismiss) var dismiss

    init(recipients: [String], subject: String, body: String = "") {
        self.recipients = recipients
        self.subject = subject
        self.body = body
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)

        // デバイス情報とアプリ情報を自動追加
        let deviceInfo = getDeviceInfo()
        let fullBody = body.isEmpty ? deviceInfo : "\(body)\n\n---\n\(deviceInfo)"
        composer.setMessageBody(fullBody, isHTML: false)

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func getDeviceInfo() -> String {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "不明"

        return """


        --- アプリ・デバイス情報 ---
        アプリ名: Darias
        アプリバージョン: \(appVersion) (\(buildNumber))
        デバイス: \(device.model)
        iOS バージョン: \(device.systemVersion)
        デバイス名: \(device.name)
        """
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            parent.dismiss()
        }
    }
}

#Preview {
    MailComposeView(
        recipients: ["test@example.com"],
        subject: "テストメール",
        body: "これはテストメールです。"
    )
}