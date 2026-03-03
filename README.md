# SiriMetra

A privacy-first iOS app for Chicagoland Metra commuters. Ask Siri "When is the next train to home?" and get an instant answer with real-time delay info.

## Features

- **Siri Integration** — Ask "When is the next train to home?" or "When is the next train to work?"
- **Real-Time Data** — Live train schedules, delays, and service alerts from Metra's GTFS API
- **Push Notifications** — Get notified about delays and service disruptions on your commute
- **Privacy First** — All data stays on your device. No tracking, no analytics, no servers.
- **GDPR Compliant** — Full privacy dashboard with data export and deletion

## Privacy Architecture

SiriMetra takes a zero-collection approach to privacy:

| What | Details |
|------|---------|
| Data stored | Station preferences, notification settings (on-device only) |
| Data transmitted | None. Zero user data leaves your device. |
| Network requests | Metra public GTFS API only (schedule/alert data) |
| Analytics | None |
| Third-party SDKs | None |
| Tracking | None |
| Servers | None — we operate no backend infrastructure |

### GDPR Rights

All exercisable directly from the in-app Privacy Dashboard:

- **Right of Access** (Art. 15) — View all stored data
- **Right to Portability** (Art. 20) — Export data as JSON
- **Right to Erasure** (Art. 17) — Delete all data instantly
- **Right to Withdraw Consent** (Art. 7) — Revoke consent and reset

## Tech Stack

- **Swift 5.9** / **SwiftUI**
- **iOS 17.0+**
- **App Intents** framework for Siri integration
- **GTFS / GTFS-RT** for Metra schedule data
- **XcodeGen** for project generation

## Getting Started

### Prerequisites

- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd Metairie

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open SiriMetra.xcodeproj
```

### Build & Run

1. Open the generated `.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run on a device or simulator (iOS 17.0+)

## Project Structure

```
SiriMetra/
├── App/                    # App entry point and delegate
├── Models/                 # Data models (Station, Route, Trip, Alert)
├── Services/               # API service, schedule engine
├── Views/                  # SwiftUI views
├── ViewModels/             # View models (MVVM)
├── Intents/                # Siri App Intents
├── Privacy/                # GDPR manager
├── Extensions/             # Swift extensions
└── Resources/              # Info.plist, assets, entitlements
```

## Metra Data Source

Schedule and real-time data comes from [Metra's public GTFS API](https://gtfsapi.metrarail.com). This is a public transit feed — no API key required for basic access.

## Legal

- Metra is a registered trademark of the Northeast Illinois Regional Commuter Railroad Corporation.
- This app is not affiliated with, endorsed by, or sponsored by Metra.
- Schedule data is provided by Metra's public GTFS feed.

## License

All rights reserved.
