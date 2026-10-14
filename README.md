# Babis Hub

Babis Hub is an internal iOS 15+ QA and demo app built with SwiftUI, MapKit, and CoreLocation coordinate types. It supports in-app coordinate selection, place search, manual latitude/longitude entry, route playback, favorites, GPX import/export, and locally persisted settings.

## Important limitation and permitted use

Location simulation is app-local: Babis Hub updates only its own map and simulated coordinate. iOS sandboxing does not let this app change system-wide GPS or another app's location, including Snapchat. It uses no private APIs, jailbreak hooks, or sandbox bypasses. Use only for authorized testing and internal demonstrations. Misuse may violate Apple Enterprise Program terms or Snapchat's Terms of Service and can result in certificate revocation, account restrictions, or bans.

## Xcode project

Open `BabisHub.xcodeproj` with Xcode 15 or later. The deployment target is iOS 15.0. The project is organized as:

```text
BabisHub/
  BabisHubApp.swift
  Models/Place.swift
  Services/LocationSimulationService.swift
  Services/GPXDocument.swift
  ViewModels/HubViewModel.swift
  Views/ContentView.swift
  Views/LibraryView.swift
  Views/MapKitPicker.swift
  Views/SettingsView.swift
  Info.plist
  BabisHub.entitlements
```

Replace `com.example.babishub` with your organization's unique app identifier in both `BabisHub.xcodeproj/project.pbxproj` and `codemagic.yaml` before signing. Build and run in the iOS Simulator or on an authorized test device.

The entitlements file is intentionally empty: there is no special location-simulation entitlement and no location permission is requested. The app's search function uses Apple's MapKit services; a network connection may be required for search and map tiles.

The `LocationSimulating` protocol is injected into the MVVM view model. `LocationSimulationService` moves an app-owned coordinate along route waypoints; it does not call `CLLocationManager` or publish a device-wide/system location.

## Enterprise distribution

1. Confirm the organization is eligible for Apple's Apple Developer Enterprise Program and that this internal-only app qualifies under the current program terms. Enterprise distribution is not a substitute for App Store distribution or external/public beta testing.
2. In Xcode, configure the organization's Team and unique bundle identifier. Enable automatic signing or select the organization's enterprise distribution provisioning profile. Do not add entitlements that are not required by the app.
3. Select **Any iOS Device (arm64)** and use **Product > Archive**. In Organizer, choose **Distribute App > Enterprise** (the exact wording may vary by Xcode version), then export/sign using the organization's approved certificate and profile.
4. Distribute the resulting signed IPA only to authorized employees/testers through the organization's managed internal distribution channel (for example, MDM). Protect the IPA, signing certificates, and provisioning profiles. Follow Apple's current certificate, device, and trust requirements.
5. Revoke or rotate distribution credentials if they are exposed, and remove access when testers no longer need it. Apple may revoke enterprise certificates for program violations, interrupting app installation or launch.

Follow Apple's latest Enterprise Program agreements and distribution documentation. Violating Apple Enterprise Program terms or Snapchat's Terms of Service can lead to enterprise certificate revocation, service/account restrictions, or bans.

## Build an IPA with Codemagic

The repository root contains `codemagic.yaml`; its `ios-enterprise` workflow archives and exports `build/ios/ipa/*.ipa`.

1. Push this repository to GitHub and add/connect it in Codemagic. Select the `main` branch and let Codemagic detect the root `codemagic.yaml`.
2. Enroll the organization in the Apple Developer Enterprise Program. In Codemagic **Team settings > codemagic.yaml settings > Code signing identities**, upload or fetch the matching Apple Distribution certificate and the app's Enterprise provisioning profile. The profile must match the bundle identifier in the YAML and Xcode project.
3. Replace the example bundle identifier in the project and YAML with the exact App ID covered by that Enterprise profile. Commit and push the change.
4. Start the `ios-enterprise` workflow. Codemagic applies the signing profile, archives the `BabisHub` scheme, and exports the signed IPA. Download it from the successful build's **Artifacts** section.

An Enterprise signing profile/certificate and organization membership are required to install the IPA on authorized employee devices. The workflow does not create or supply Apple signing credentials; never commit certificates, private keys, provisioning profiles, or API keys to the repository. For unsigned simulator builds or App Store/TestFlight distribution, create a separate workflow with the appropriate destination and signing type rather than using the Enterprise workflow.

## Data and GPX behavior

Favorites, routes, and the default simulation speed are encoded as Codable data in `UserDefaults` on the device. GPX imports accept route, track, and waypoint points; an imported route needs at least two valid points. GPX exports contain the selected saved route.
