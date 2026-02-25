import Foundation
import Combine

@MainActor
class XPCHealthChecker: ObservableObject {
    @Published var isReachable = false
    @Published var isChecking = false

    private var monitorTask: Task<Void, Never>?

    func startMonitoring() {
        check()
        monitorTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if !Task.isCancelled { check() }
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func check() {
        isChecking = true

        Task.detached {
            let reachable = await self.probeXPC()
            await MainActor.run {
                self.isReachable = reachable
                self.isChecking = false
            }
        }
    }

    nonisolated func probeXPC() async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NSXPCConnection(machServiceName: "com.setapp.ProvisioningService", options: [])
            connection.remoteObjectInterface = NSXPCInterface(with: NSObjectProtocol.self)

            var didResume = false
            let resume = { (result: Bool) in
                if !didResume {
                    didResume = true
                    continuation.resume(returning: result)
                }
            }

            connection.invalidationHandler = { resume(false) }
            connection.interruptionHandler = { resume(false) }
            connection.resume()

            let _ = connection.remoteObjectProxyWithErrorHandler { _ in
                resume(false)
            }

            // If we got here without error, service is reachable
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [connection] in
                resume(true)
                connection.invalidate()
            }
        }
    }
}
