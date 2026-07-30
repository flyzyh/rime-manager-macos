import SwiftUI

/// Toast notification view for user feedback.
struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(toast.color)

            Text(toast.text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .adaptiveGlassClear(cornerRadius: 20)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .padding(.bottom, 16)
    }
}
