import Foundation

struct AppSettings {
    static let installPathKey = "installPath"
    static let postInstallActionKey = "postInstallAction"
    static let postUpdateActionKey = "postUpdateAction"
    static let deleteActionKey = "deleteAction"

    static let defaultInstallPath = "/Applications/Setapp"
    static let defaultPostInstallAction = "open \"$APP\""
    static let defaultPostUpdateAction = ""
    static let defaultDeleteAction = "/Applications/AppCleaner.app/Contents/MacOS/AppCleaner \"$APP\""

    static func runAction(_ template: String, appPath: String) {
        guard !template.isEmpty else { return }
        let command = template.replacingOccurrences(of: "$APP", with: appPath)
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            try? process.run()
        }
    }
}
