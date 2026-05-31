import SwiftUI

struct RecentPathRow: View {
    let output: String
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(output)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(output)

            Button {
                onCopy()
            } label: {
                Image(systemName: "doc.on.doc")
                    .accessibilityLabel("Copy")
            }
            .buttonStyle(.borderless)
            .help("Copy again")
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 7)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
    }
}
