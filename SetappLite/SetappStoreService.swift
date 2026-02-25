import Foundation
import Combine

@MainActor
class SetappStoreService: ObservableObject {
    @Published var apps: [SetappApp] = []
    @Published var isLoading = false
    @Published var error: String?

    private let storeURL = URL(string: "https://store.setapp.com/store/api/v8/en")!

    func fetchApps() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: storeURL)
            apps = try parseStoreResponse(data)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func parseStoreResponse(_ data: Data) throws -> [SetappApp] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let root = json["data"] as? [String: Any],
              let relationships = root["relationships"] as? [String: Any],
              let vendors = relationships["vendors"] as? [String: Any],
              let vendorList = vendors["data"] as? [[String: Any]]
        else { return [] }

        var result: [SetappApp] = []
        for vendor in vendorList {
            let vendorName = (vendor["attributes"] as? [String: Any])?["name"] as? String ?? ""
            guard let rels = vendor["relationships"] as? [String: Any],
                  let appsRel = rels["applications"] as? [String: Any],
                  let appList = appsRel["data"] as? [[String: Any]]
            else { continue }

            for app in appList {
                guard let id = app["id"] as? Int,
                      let attrs = app["attributes"] as? [String: Any],
                      let name = attrs["name"] as? String
                else { continue }

                let iconStr = attrs["icon"] as? String

                // Get latest version info from versions relationship
                var latestVersion: String?
                var archiveURL: URL?
                var size: Int64?
                if let appRels = app["relationships"] as? [String: Any],
                   let versionsRel = appRels["versions"] as? [String: Any],
                   let versionsList = versionsRel["data"] as? [[String: Any]],
                   let latest = versionsList.first,
                   let vAttrs = latest["attributes"] as? [String: Any] {
                    latestVersion = vAttrs["marketing_version"] as? String
                    archiveURL = (vAttrs["archive_url"] as? String).flatMap { URL(string: $0) }
                    size = (vAttrs["size"] as? NSNumber)?.int64Value
                }

                result.append(SetappApp(
                    id: id,
                    name: name,
                    shortDescription: attrs["cta_description"] as? String ?? "",
                    bundleID: attrs["bundle_id"] as? String ?? "",
                    iconURL: iconStr.flatMap { URL(string: $0) },
                    vendorName: vendorName,
                    latestVersion: latestVersion,
                    archiveURL: archiveURL,
                    description: attrs["description"] as? String ?? "",
                    bullets: attrs["bullets"] as? [String] ?? [],
                    marketingURL: (attrs["marketing_url"] as? String).flatMap { URL(string: $0) },
                    size: size
                ))
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
