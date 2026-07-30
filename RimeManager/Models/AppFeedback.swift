import SwiftUI

// MARK: - Toast Message

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let style: Style

    enum Style {
        case success
        case error
        case info
    }

    var icon: String {
        switch style {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch style {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }
}

// MARK: - Alert Message

struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let style: NSAlert.Style

    init(title: String, message: String, style: NSAlert.Style = .warning) {
        self.title = title
        self.message = message
        self.style = style
    }

    static func from(_ error: AppError) -> AlertMessage {
        AlertMessage(
            title: "alert.error_title".localized,
            message: error.localizedDescription,
            style: .warning
        )
    }
}

// MARK: - Feedback Manager

/// Central manager for user feedback (toasts and alerts).
@MainActor
final class FeedbackManager: ObservableObject {
    @Published var toast: ToastMessage?
    @Published var alert: AlertMessage?

    private var toastTask: Task<Void, Never>?

    static let shared = FeedbackManager()

    private init() {}

    // MARK: - Toast

    func showSuccess(_ text: String) {
        showToast(text, style: .success)
    }

    func showError(_ text: String) {
        showToast(text, style: .error)
    }

    func showInfo(_ text: String) {
        showToast(text, style: .info)
    }

    func showToast(_ text: String, style: ToastMessage.Style, duration: TimeInterval = 3.0) {
        toastTask?.cancel()
        toast = ToastMessage(text: text, style: style)
        toastTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                toast = nil
            }
        }
    }

    // MARK: - Alert

    func showAlert(_ title: String, message: String, style: NSAlert.Style = .warning) {
        alert = AlertMessage(title: title, message: message, style: style)
    }

    func showAlert(for error: AppError) {
        alert = AlertMessage.from(error)
    }

    func dismissAlert() {
        alert = nil
    }
}
