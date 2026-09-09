# STAGE 2 — Profile

## Objective
Implement the first-launch experience, user profile creation, and persistent local storage to establish the identity and primary configuration of the application.

## Implemented Features
- **Onboarding Experience:** Beautiful welcome screen utilizing the app's dark-first design system and the provided banner image (`folowmylifebanner.webp`).
- **Profile Creation:** Captured the user's name to initialize the SQLite database via Drift.
- **State Hydration:** Handled the `hasProfile` check during application startup in `main.dart` to automatically route users to either the `/onboarding` screen or the `HomePage` (`/`).
- **Profile Screen:** 
  - Dynamic avatar generation based on the user's first letter.
  - Settings layout using custom `GlassCard`-inspired ListTiles.
  - Placeholders for future settings like Currency, Theme, and Backup.

## Architecture Decisions
- Used `Riverpod` `StreamProvider` to watch the `UserProfiles` table. When the profile is created during onboarding, it triggers a UI update, allowing seamless routing to the Home screen without full app restarts.
- Kept the profile simple (Name, Currency) but modeled the database for future additions (Theme preference, Language).

## Files Changed/Added
- `lib/main.dart`
- `lib/features/profile/presentation/pages/onboarding_page.dart`
- `lib/features/profile/presentation/pages/profile_page.dart`

## Known Limitations
- Currency is currently locked to DZD in the backend, though the UI shows it.
- Theme switching is tied to the system theme; manual overrides in settings are UI placeholders.

## Next Stage
Proceed to **STAGE 3 — Money Sources**.
