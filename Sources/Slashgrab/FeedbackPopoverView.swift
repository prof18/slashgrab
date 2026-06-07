import SwiftUI

struct FeedbackPopoverView: View {
    let feedback: DropFeedback

    var body: some View {
        StatusPopoverContentView(
            systemImage: feedback.kind == .success ? "checkmark.circle.fill" : "xmark.octagon.fill",
            iconColor: feedback.kind == .success ? .green : .red,
            title: feedback.message,
            detail: feedback.detail
        )
    }
}

struct DropReadyPopoverView: View {
    var body: some View {
        StatusPopoverContentView(
            systemImage: "arrow.down.circle.fill",
            iconColor: .accentColor,
            title: "Ready to drop",
            detail: "Release to copy path"
        )
    }
}

private struct StatusPopoverContentView: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    let detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Avenir Next", size: 13).weight(.semibold))
                    .lineLimit(1)

                if let detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: 280, height: 66)
        .background(.regularMaterial)
    }
}
