# SECURITY & APP LOCK SPECIFICATION

## 1. ARCHITECTURE
- **PIN Verification:** Standard 4-digit or 6-digit Security PIN stored securely via `FlutterSecureStorage` with PBKDF2/SHA-256 key hashing and random salt.
- **Biometric Authentication:** Uses `local_auth` package supporting Fingerprint, Face ID, and Iris authentication.
- **Lifecycle Auto-Lock:** Monitors app lifecycle state (`AppLifecycleState.paused` / `resumed`). Automatically triggers lock screen after configurable inactivity timeout (default: 5 minutes) or immediate backgrounding.
- **Platform Configuration:**
  - Android: `MainActivity` extends `FlutterFragmentActivity` with `USE_BIOMETRIC` permission.
  - iOS: `NSFaceIDUsageDescription` configured in `Info.plist`.
