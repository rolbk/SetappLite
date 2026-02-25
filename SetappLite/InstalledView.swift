import SwiftUI

struct InstalledView: View {
    @ObservedObject var service: InstalledAppsService
    @ObservedObject var storeService: SetappStoreService
    @ObservedObject var updateService: UpdateService
    @ObservedObject var logService: LogService
    @State private var isCheckingUpdates = false

    private var appsWithUpdates: [(InstalledApp, SetappApp)] {
        service.apps.compactMap { installed in
            guard let bundleID = installed.bundleID,
                  let storeApp = storeService.apps.first(where: { $0.bundleID == bundleID }),
                  let remote = storeApp.latestVersion,
                  let local = installed.version,
                  isNewer(remote: remote, local: local),
                  storeApp.archiveURL != nil,
                  updateService.appProgress[bundleID] == nil
            else { return nil }
            return (installed, storeApp)
        }
    }

    var body: some View {
        Group {
            if service.apps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No apps installed in /Applications/Setapp")
                        .foregroundStyle(.secondary)
                }
            } else {
                List(service.apps) { app in
                    InstalledAppRow(
                        app: app,
                        storeApp: storeService.apps.first { $0.bundleID == app.bundleID },
                        updateService: updateService,
                        logService: logService
                    )
                }
            }
        }
        .navigationTitle("Installed")
        .toolbar {
            ToolbarItemGroup {
                if !appsWithUpdates.isEmpty {
                    Button {
                        let updates = appsWithUpdates
                        Task {
                            for (_, storeApp) in updates {
                                await updateService.install(app: storeApp, isUpdate: true)
                                service.refresh()
                            }
                        }
                    } label: {
                        Label("Update All (\(appsWithUpdates.count))", systemImage: "arrow.down.circle")
                    }
                    .help("Update all apps")
                }

                Button {
                    isCheckingUpdates = true
                    Task {
                        await updateService.checkAndUpdate(storeService: storeService, installedService: service)
                        isCheckingUpdates = false
                    }
                } label: {
                    if isCheckingUpdates {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    } else {
                        Label("Check for Updates", systemImage: "arrow.clockwise")
                    }
                }
                .help("Check for updates now")
                .disabled(isCheckingUpdates)
            }
        }
    }

    private func isNewer(remote: String, local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}

struct InstalledAppRow: View {
    let app: InstalledApp
    let storeApp: SetappApp?
    @ObservedObject var updateService: UpdateService
    @ObservedObject var logService: LogService

    private var progress: AppProgress? {
        app.bundleID.flatMap { updateService.appProgress[$0] }
    }

    private var hasUpdate: Bool {
        guard let local = app.version,
              let remote = storeApp?.latestVersion else { return false }
        return isNewer(remote: remote, local: local)
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "app")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    if let version = app.version {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let progress {
                        ProgressIndicator(progress: progress)
                    } else if hasUpdate, let remote = storeApp?.latestVersion {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text(remote)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            if hasUpdate, progress == nil, let storeApp {
                Button("Update") {
                    Task { await updateService.install(app: storeApp, isUpdate: true) }
                }
                .controlSize(.small)
            }

            Button {
                runDeleteAction(app)
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete")
            .controlSize(.small)

            Button("Open") {
                NSWorkspace.shared.open(app.bundlePath)
            }
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }

    private func runDeleteAction(_ app: InstalledApp) {
        let action = UserDefaults.standard.string(forKey: AppSettings.deleteActionKey) ?? AppSettings.defaultDeleteAction
        AppSettings.runAction(action, appPath: app.bundlePath.path(percentEncoded: false))
        logService.log(.deleted, app: app.name)
    }

    private func isNewer(remote: String, local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
