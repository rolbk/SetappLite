import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case browse = "Browse"
    case installed = "Installed"
    case log = "Activity"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .browse: "magnifyingglass"
        case .installed: "square.grid.2x2"
        case .log: "clock.arrow.circlepath"
        case .settings: "gear"
        }
    }
}

struct ContentView: View {
    @StateObject private var storeService = SetappStoreService()
    @StateObject private var installedService = InstalledAppsService()
    @StateObject private var xpcChecker = XPCHealthChecker()
    @StateObject private var updateService = UpdateService()
    @StateObject private var logService = LogService()
    @State private var selectedItem: SidebarItem? = .browse
    @State private var showAgentAlert = false
    @State private var showErrorAlert = false
    @State private var errorAlertTitle = ""
    @State private var errorAlertMessage = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(SidebarItem.allCases) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.icon)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .safeAreaInset(edge: .bottom) {
                AgentStatusButton(checker: xpcChecker) {
                    if xpcChecker.isReachable {
                        xpcChecker.check()
                    } else {
                        showAgentAlert = true
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        } detail: {
            switch selectedItem {
            case .browse:
                BrowseView(storeService: storeService, installedService: installedService, updateService: updateService)
            case .installed:
                InstalledView(service: installedService, storeService: storeService, updateService: updateService, logService: logService)
            case .log:
                LogView(logService: logService)
            case .settings:
                SettingsView()
            case nil:
                Text("Select an item")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            xpcChecker.startMonitoring()
            installedService.startMonitoring()
            Task { await storeService.fetchApps() }
            updateService.logService = logService
            updateService.startMonitoring(storeService: storeService, installedService: installedService)
        }
        .onDisappear {
            xpcChecker.stopMonitoring()
            installedService.stopMonitoring()
            updateService.stopMonitoring()
        }
        .task {
            // Wait for initial check to complete
            try? await Task.sleep(for: .seconds(2))
            if !xpcChecker.isReachable {
                showAgentAlert = true
            }
        }
        .alert("Setapp Agent Required", isPresented: $showAgentAlert) {
            Button("OK") {}
        } message: {
            Text("The official Setapp desktop client must be installed and you must be logged in with a valid subscription for app licensing to work.\n\nPlease install Setapp from setapp.com and sign in.")
        }
        .alert(errorAlertTitle, isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorAlertMessage)
        }
        .onChange(of: updateService.lastError?.appName) {
            if let err = updateService.lastError {
                errorAlertTitle = "Install Failed: \(err.appName)"
                errorAlertMessage = err.message
                showErrorAlert = true
                updateService.lastError = nil
            }
        }
    }
}

struct AgentStatusButton: View {
    @ObservedObject var checker: XPCHealthChecker
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(checker.isReachable ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(checker.isReachable ? "Agent Connected" : "Agent Offline")
                    .font(.caption)
                    .foregroundStyle(checker.isReachable ? .secondary : .primary)
                Spacer()
                if checker.isChecking {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(checker.isReachable ? .clear : .red.opacity(0.1))
                    .strokeBorder(checker.isReachable ? Color.secondary.opacity(0.2) : Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
