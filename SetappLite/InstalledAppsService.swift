import Foundation
import Combine
import AppKit

@MainActor
class InstalledAppsService: ObservableObject {
    @Published var apps: [InstalledApp] = []

    private var setappDir: URL {
        let path = UserDefaults.standard.string(forKey: AppSettings.installPathKey) ?? AppSettings.defaultInstallPath
        return URL(fileURLWithPath: path)
    }
    private var monitorTask: Task<Void, Never>?

    func startMonitoring() {
        refresh()
        monitorTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                if !Task.isCancelled { refresh() }
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func refresh() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: setappDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            apps = []
            return
        }

        apps = contents
            .filter { $0.pathExtension == "app" }
            .compactMap { url in
                let bundle = Bundle(url: url)
                let name = url.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                return InstalledApp(
                    id: url.path,
                    name: name,
                    bundlePath: url,
                    bundleID: bundle?.bundleIdentifier,
                    icon: icon,
                    version: bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
