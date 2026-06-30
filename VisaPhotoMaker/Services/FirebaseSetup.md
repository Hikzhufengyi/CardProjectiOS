# Firebase Analytics Setup

The iOS app is wired for Firebase Analytics events, but local builds require the Firebase iOS config file:

1. In Firebase Console, add an iOS app with bundle ID `com.indie.visaphotomaker`.
2. Download `GoogleService-Info.plist`.
3. Put it under `VisaPhotoMaker/GoogleService-Info.plist` in this Xcode project.

Tracked product funnel events:

- `app_open`
- `onboarding_complete`
- `spec_select`
- `photo_import`
- `check_complete`
- `export_attempt`
- `export_success`
- `purchase_start`
- `purchase_success`
- `purchase_failure`
- `restore_purchase`
