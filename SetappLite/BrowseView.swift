import SwiftUI

struct BrowseView: View {
    @ObservedObject var storeService: SetappStoreService
    @ObservedObject var installedService: InstalledAppsService
    @ObservedObject var updateService: UpdateService
    @State private var searchText = ""
    @State private var selectedApp: SetappApp?

    private var filteredApps: [SetappApp] {
        if searchText.isEmpty { return storeService.apps }
        return storeService.apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.shortDescription.localizedCaseInsensitiveContains(searchText) ||
            $0.vendorName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HSplitView {
            // App list
            Group {
                if storeService.isLoading {
                    ProgressView("Loading apps...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = storeService.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await storeService.fetchApps() }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredApps, selection: $selectedApp) { app in
                        AppRowView(
                            app: app,
                            isInstalled: installedService.apps.contains { $0.bundleID == app.bundleID },
                            updateService: updateService
                        )
                        .tag(app)
                    }
                }
            }
            .frame(minWidth: 280)

            // Detail pane
            if let app = selectedApp {
                AppDetailView(
                    app: app,
                    isInstalled: installedService.apps.contains { $0.bundleID == app.bundleID },
                    installedApp: installedService.apps.first { $0.bundleID == app.bundleID },
                    updateService: updateService
                )
                .frame(minWidth: 300)
            } else {
                Text("Select an app")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: 300)
            }
        }
        .searchable(text: $searchText, prompt: "Search apps")
        .navigationTitle("Browse")
    }
}

struct AppRowView: View {
    let app: SetappApp
    let isInstalled: Bool
    @ObservedObject var updateService: UpdateService

    private var progress: AppProgress? {
        updateService.appProgress[app.bundleID]
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: app.iconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "app")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .fontWeight(.medium)
                Text(app.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let progress {
                ProgressIndicator(progress: progress)
            } else if isInstalled {
                Text("Installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            } else {
                Button("Get") {
                    Task { await updateService.install(app: app) }
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ProgressIndicator: View {
    let progress: AppProgress

    var body: some View {
        switch progress {
        case .downloading(let fraction):
            VStack(spacing: 2) {
                ProgressView(value: fraction)
                    .frame(width: 80)
                Text("\(Int(fraction * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .installing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text("Installing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
