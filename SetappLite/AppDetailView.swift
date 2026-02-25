import SwiftUI

struct AppDetailView: View {
    let app: SetappApp
    let isInstalled: Bool
    let installedApp: InstalledApp?
    @ObservedObject var updateService: UpdateService

    private var progress: AppProgress? {
        updateService.appProgress[app.bundleID]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    AsyncImage(url: app.iconURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        default:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.quaternary)
                                .overlay {
                                    Image(systemName: "app")
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(app.shortDescription)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text(app.vendorName)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            if let version = app.latestVersion {
                                Text("v\(version)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Spacer()

                    VStack(spacing: 6) {
                        if let progress {
                            ProgressIndicator(progress: progress)
                        } else if isInstalled {
                            HStack(spacing: 8) {
                                Text("Installed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.quaternary, in: Capsule())
                                if let installedApp {
                                    Button("Open") {
                                        NSWorkspace.shared.open(installedApp.bundlePath)
                                    }
                                    .controlSize(.small)
                                }
                            }
                        } else {
                            Button("Get") {
                                Task { await updateService.install(app: app) }
                            }
                            .controlSize(.large)
                        }
                        if let size = app.size, size > 0 {
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Divider()

                // Bullets
                if !app.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(app.bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                    .padding(.top, 2)
                                Text(bullet)
                                    .font(.callout)
                            }
                        }
                    }
                }

                // Description
                if !app.description.isEmpty {
                    DescriptionView(markdown: app.description)
                }

                // Links
                HStack(spacing: 16) {
                    if let url = app.marketingURL {
                        Link(destination: url) {
                            Label("Website", systemImage: "safari")
                                .font(.callout)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

}

private struct DescriptionView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                if let heading = section.heading {
                    Text(heading)
                        .font(.headline)
                }
                if !section.body.isEmpty {
                    Text(inlineMarkdown(section.body))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private struct Section {
        var heading: String?
        var body: String
    }

    private var sections: [Section] {
        var result: [Section] = []
        var currentHeading: String? = nil
        var currentBody: [String] = []

        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") || trimmed.hasPrefix("# ") {
                // Flush previous section
                if currentHeading != nil || !currentBody.isEmpty {
                    result.append(Section(heading: currentHeading, body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentHeading = trimmed.drop(while: { $0 == "#" || $0 == " " }).trimmingCharacters(in: .whitespaces)
                currentBody = []
            } else {
                currentBody.append(line)
            }
        }
        // Flush last section
        if currentHeading != nil || !currentBody.isEmpty {
            result.append(Section(heading: currentHeading, body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return result
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}
