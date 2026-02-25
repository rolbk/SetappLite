import Foundation
import Combine
import ZIPFoundation

enum AppProgress: Equatable {
    case downloading(fraction: Double)
    case installing
}

// Thread-safe storage for download delegate state
private final class DownloadState: Sendable {
    private let lock = NSLock()
    private var _continuations: [Int: CheckedContinuation<URL, any Error>] = [:]
    private var _bundleIDs: [Int: String] = [:]

    func register(taskID: Int, bundleID: String, continuation: CheckedContinuation<URL, any Error>) {
        lock.lock()
        _continuations[taskID] = continuation
        _bundleIDs[taskID] = bundleID
        lock.unlock()
    }

    func bundleID(for taskID: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return _bundleIDs[taskID]
    }

    func complete(taskID: Int) -> CheckedContinuation<URL, any Error>? {
        lock.lock()
        let cont = _continuations.removeValue(forKey: taskID)
        _bundleIDs.removeValue(forKey: taskID)
        lock.unlock()
        return cont
    }
}

@MainActor
class UpdateService: NSObject, ObservableObject {
    @Published var appProgress: [String: AppProgress] = [:]
    @Published var lastError: (appName: String, message: String)?

    var logService: LogService?
    private var monitorTask: Task<Void, Never>?
    private var installDir: URL {
        let path = UserDefaults.standard.string(forKey: AppSettings.installPathKey) ?? AppSettings.defaultInstallPath
        return URL(fileURLWithPath: path)
    }
    private let downloadState = DownloadState()
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    func startMonitoring(storeService: SetappStoreService, installedService: InstalledAppsService) {
        monitorTask = Task {
            try? await Task.sleep(for: .seconds(10))
            while !Task.isCancelled {
                await checkAndUpdate(storeService: storeService, installedService: installedService)
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func checkAndUpdate(storeService: SetappStoreService, installedService: InstalledAppsService) async {
        for installed in installedService.apps {
            guard let bundleID = installed.bundleID,
                  let storeApp = storeService.apps.first(where: { $0.bundleID == bundleID }),
                  let remoteVersion = storeApp.latestVersion,
                  let localVersion = installed.version,
                  isNewer(remote: remoteVersion, local: localVersion),
                  storeApp.archiveURL != nil,
                  appProgress[bundleID] == nil
            else { continue }

            await install(app: storeApp, isUpdate: true)
            installedService.refresh()
        }
    }

    func install(app: SetappApp, isUpdate: Bool = false) async {
        guard let archiveURL = app.archiveURL, appProgress[app.bundleID] == nil else { return }
        appProgress[app.bundleID] = .downloading(fraction: 0)

        do {
            let tempZip = try await downloadWithProgress(url: archiveURL, bundleID: app.bundleID)

            appProgress[app.bundleID] = .installing

            let targetDir = installDir
            let destinationPath: String = try await Task.detached {
                let fm = FileManager.default
                let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)

                if !fm.fileExists(atPath: targetDir.path(percentEncoded: false)) {
                    try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
                }

                try FileManager.default.unzipItem(at: tempZip, to: tempDir)

                // Find .app recursively (some archives have a SetappPayload/ wrapper)
                guard let extractedApp = Self.findApp(in: tempDir) else {
                    throw NSError(domain: "UpdateService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No .app found in archive"])
                }

                let destination = targetDir.appendingPathComponent(extractedApp.lastPathComponent)
                if fm.fileExists(atPath: destination.path(percentEncoded: false)) {
                    try fm.removeItem(at: destination)
                }
                try fm.moveItem(at: extractedApp, to: destination)

                try? fm.removeItem(at: tempDir)
                try? fm.removeItem(at: tempZip)

                return destination.path(percentEncoded: false)
            }.value

            print("Successfully installed \(app.name)")
            logService?.log(isUpdate ? .updated : .installed, app: app.name)

            // Run post-action
            let actionKey = isUpdate ? AppSettings.postUpdateActionKey : AppSettings.postInstallActionKey
            let defaultAction = isUpdate ? AppSettings.defaultPostUpdateAction : AppSettings.defaultPostInstallAction
            let action = UserDefaults.standard.string(forKey: actionKey) ?? defaultAction
            AppSettings.runAction(action, appPath: destinationPath)
        } catch {
            print("Install failed for \(app.name): \(error)")
            let msg = (error as NSError).localizedDescription
            logService?.log(.failed, app: app.name, detail: msg)
            lastError = (appName: app.name, message: msg)
        }

        appProgress.removeValue(forKey: app.bundleID)
    }

    private nonisolated static func findApp(in directory: URL) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return nil }
        for case let url as URL in enumerator {
            if url.pathExtension == "app" {
                enumerator.skipDescendants()
                return url
            }
        }
        return nil
    }

    private func downloadWithProgress(url: URL, bundleID: String) async throws -> URL {
        let state = downloadState
        let sess = session
        return try await withCheckedThrowingContinuation { continuation in
            let task = sess.downloadTask(with: url)
            state.register(taskID: task.taskIdentifier, bundleID: bundleID, continuation: continuation)
            task.resume()
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

extension UpdateService: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fraction = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        let bid = downloadState.bundleID(for: downloadTask.taskIdentifier)
        if let bid {
            Task { @MainActor in
                self.appProgress[bid] = .downloading(fraction: fraction)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        try? FileManager.default.moveItem(at: location, to: dest)
        downloadState.complete(taskID: downloadTask.taskIdentifier)?.resume(returning: dest)
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error else { return }
        downloadState.complete(taskID: task.taskIdentifier)?.resume(throwing: error)
    }
}
