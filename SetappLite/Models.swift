import Foundation
import AppKit

struct SetappApp: Identifiable, Hashable {
    let id: Int
    let name: String
    let shortDescription: String
    let bundleID: String
    let iconURL: URL?
    let vendorName: String
    let latestVersion: String?
    let archiveURL: URL?
    let description: String
    let bullets: [String]
    let marketingURL: URL?
    let size: Int64? // bytes
}

struct InstalledApp: Identifiable {
    let id: String // bundle path
    let name: String
    let bundlePath: URL
    let bundleID: String?
    let icon: NSImage?
    let version: String?
}
