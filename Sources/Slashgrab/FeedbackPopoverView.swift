import SwiftUI

struct FeedbackPopoverView: View {
    let feedback: DropFeedback

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: feedback.kind == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(feedback.kind == .success ? .green : .red)

            Text(feedback.message)
                .font(.custom("Avenir Next", size: 13).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: 188, height: 46)
        .background(.regularMaterial)
    }
}
