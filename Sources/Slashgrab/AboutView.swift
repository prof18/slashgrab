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
        ScrollView {
            VStack(spacing: 20) {
                Image(nsImage: AppIconProvider.image())
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)

                HStack(spacing: 10) {
                    Text(appName)
                        .font(.system(size: 36, weight: .bold))

                    if buildInfo.isDevBuild {
                        Text("DEV")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 6))
                    }
                }

                Text(versionLine)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Drop files on the menu bar and copy clean filesystem paths instantly.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .padding(.top, 4)

                VStack(spacing: 14) {
                    ForEach(links) { link in
                        Link(destination: link.url) {
                            Label(link.title, systemImage: link.systemImage)
                                .font(.title2.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)

                Button(action: onCheckForUpdates) {
                    Text("Check for Updates")
                        .font(.body)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!canCheckForUpdates)
                .padding(.top, 8)

                if let copyright {
                    Text(copyright)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 36)
        }
        .frame(minWidth: 560, minHeight: 560)
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
                rawURL: "https://www.marcogomiero.com/"
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
