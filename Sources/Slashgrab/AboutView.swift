import AppKit
import SwiftUI

struct AboutView: View {
    let buildInfo: AppBuildInfo
    let canCheckForUpdates: Bool
    let onCheckForUpdates: () -> Void

    private struct AboutLink: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let url: URL
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                aboutContent
                    .padding(28)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
    }

    private var aboutContent: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                Image(nsImage: AppIconProvider.image())
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(appName)
                            .font(.custom("Avenir Next", size: 26, relativeTo: .title).weight(.bold))

                        if buildInfo.isDevBuild {
                            Text("DEV")
                                .font(.custom("Avenir Next", size: 9, relativeTo: .caption2).weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.orange, in: RoundedRectangle(cornerRadius: 5))
                        }
                    }

                    Text(versionLine)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Drop files on the menu bar and copy clean filesystem paths instantly.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                ForEach(links) { link in
                    Link(destination: link.url) {
                        Label(link.title, systemImage: link.systemImage)
                    }
                }
            }

            Button("Check for Updates", action: onCheckForUpdates)
                .disabled(!canCheckForUpdates)

            if let copyright {
                Text(copyright)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var links: [AboutLink] {
        [
            makeLink(
                id: "github",
                title: "GitHub",
                systemImage: "chevron.left.forwardslash.chevron.right",
                rawURL: "https://github.com/prof18/slashgrab"
            ),
            makeLink(
                id: "website",
                title: "Website",
                systemImage: "globe",
                rawURL: "https://slashgrab.app/"
            ),
        ].compactMap { $0 }
    }

    private func makeLink(id: String, title: String, systemImage: String, rawURL: String) -> AboutLink? {
        guard let url = URL(string: rawURL), !rawURL.isEmpty else {
            return nil
        }

        return AboutLink(id: id, title: title, systemImage: systemImage, url: url)
    }

    private var appName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }

        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }

        return "Slashgrab"
    }

    private var versionLine: String {
        "Version \(shortVersion) (\(buildNumber))"
    }

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var copyright: String? {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
    }
}
