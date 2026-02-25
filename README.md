# SetappLite

Fully vibecoded custom client for Setapp installations, because I was annoyed with their buggy app.

> **This app requires an active Setapp membership and the official Setapp agent installed and signed in. It only replaces the frontend — licensing still goes through Setapp's own XPC service.**

## Vibe-coded Features

A lightweight native macOS app (SwiftUI) that replaces the official Setapp desktop client for browsing, installing, and managing Setapp apps.

- **Browse & Install** — Search the full Setapp catalog, view app details, and install with one click. Live download progress included.
- **Installed Apps** — Lists your installed Setapp apps with version info, manual update buttons, and configurable delete actions (defaults to AppCleaner).
- **Auto-Updates** — Background update checker that automatically downloads and installs new versions every 5 minutes.
- **Activity Log** — Tracks installs, updates, deletes, and failures with timestamps.
- **Settings** — Custom install directory, configurable shell commands for post-install, post-update, and delete actions using `$APP` as placeholder.
- **Agent Status** — Monitors `com.setapp.ProvisioningService` XPC reachability and warns on startup if the agent isn't running.

## Building

Requires macOS 14+ and Xcode 15+. Open the project and hit Run. No dependencies.
