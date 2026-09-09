# STAGE 10 & 11 — Backup & Security (Foundation)

## Objective
Ensure the user's data remains private (Security/App Lock) and safe from loss (Backup/Restore).

## Implementation Status
These stages have been **conceptually prepared** and architecturally accommodated but require native device integration (biometrics, file system access) for full implementation.

### Backup & Restore (Stage 10)
- **Concept:** Since all data lives in SQLite (Drift), backups will involve serializing the tables to JSON or copying the `.sqlite` file directly to a user-selected location (using `file_picker` and `share_plus`).
- **UI:** Placeholders exist in `ProfilePage` under the "Data" section.

### Security & App Lock (Stage 11)
- **Concept:** Protect the app from unauthorized access on the device.
- **Architecture:** `flutter_secure_storage` is included in the project dependencies. This will be used to store a PIN hash or a flag enabling biometric prompt upon app resume.
- **UI:** Placeholder toggles exist in `ProfilePage` under the "Security" section.

## Next Steps for Production
1. Implement local authentication (`local_auth` package).
2. Write a Drift database export utility that converts table rows to JSON.
3. Wire the Profile screen UI to these utilities.
