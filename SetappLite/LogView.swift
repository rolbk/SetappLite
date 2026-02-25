import SwiftUI

struct LogView: View {
    @ObservedObject var logService: LogService

    var body: some View {
        Group {
            if logService.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No activity yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(logService.entries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.event.icon)
                            .foregroundStyle(entry.event.color)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(entry.appName)
                                    .fontWeight(.medium)
                                Text(entry.event.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(entry.event.color)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(entry.event.color.opacity(0.1), in: Capsule())
                            }
                            HStack(spacing: 8) {
                                Text(entry.date, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                if let detail = entry.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Activity")
    }
}

extension LogEntry.Event {
    var icon: String {
        switch self {
        case .installed: "arrow.down.circle.fill"
        case .updated: "arrow.up.circle.fill"
        case .deleted: "trash.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .installed: .green
        case .updated: .blue
        case .deleted: .orange
        case .failed: .red
        }
    }
}
