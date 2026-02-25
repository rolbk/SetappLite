import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.installPathKey) private var installPath = AppSettings.defaultInstallPath
    @AppStorage(AppSettings.postInstallActionKey) private var postInstallAction = AppSettings.defaultPostInstallAction
    @AppStorage(AppSettings.postUpdateActionKey) private var postUpdateAction = AppSettings.defaultPostUpdateAction
    @AppStorage(AppSettings.deleteActionKey) private var deleteAction = AppSettings.defaultDeleteAction

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Install Location
                VStack(alignment: .leading, spacing: 6) {
                    Text("Install Location")
                        .font(.headline)
                    Text("Directory where Setapp apps are installed to.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Path", text: $installPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.directoryURL = URL(fileURLWithPath: installPath)
                            if panel.runModal() == .OK, let url = panel.url {
                                installPath = url.path(percentEncoded: false)
                            }
                        }
                    }
                }

                Divider()

                // Actions
                VStack(alignment: .leading, spacing: 6) {
                    Text("Actions")
                        .font(.headline)
                    Text("Shell commands run via /bin/zsh -c. Use **$APP** as placeholder for the full app path. Chain multiple commands with **&&** or **;**.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ActionField(label: "Post-Install", command: $postInstallAction)
                    ActionField(label: "Post-Update", command: $postUpdateAction)
                    ActionField(label: "Delete", command: $deleteAction)
                }

                Divider()

                Button("Reset to Defaults") {
                    installPath = AppSettings.defaultInstallPath
                    postInstallAction = AppSettings.defaultPostInstallAction
                    postUpdateAction = AppSettings.defaultPostUpdateAction
                    deleteAction = AppSettings.defaultDeleteAction
                }
            }
            .padding(24)
        }
        .navigationTitle("Settings")
    }
}

private struct ActionField: View {
    let label: String
    @Binding var command: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Command", text: $command)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
        }
    }
}
