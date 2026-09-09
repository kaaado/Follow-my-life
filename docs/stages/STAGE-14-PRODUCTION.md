# STAGE 14 — Production Readiness & Deployment

## Objective
Transition the application from a development environment to a polished, release-ready product suitable for the Google Play Store and Apple App Store. This stage finalizes performance optimization, branding, and deployment pipelines.

## Pre-Release Checklist

### 1. Branding & Assets
- **App Icons:** Generate and configure high-resolution adaptive launcher icons for Android and iOS using the `flutter_launcher_icons` package.
- **Splash Screen:** Implement a seamless native splash screen using `flutter_native_splash` to bridge the gap between app launch and the initial Flutter render, ensuring the app feels instantly responsive.
- **Store Metadata:** Prepare screenshots, promotional text, keywords, and a comprehensive Privacy Policy (crucial since the app handles financial data, even locally).

### 2. Performance Profiling & Optimization
- **Profile Mode Analysis:** Run the app exclusively in `--profile` mode on physical devices to identify and eliminate UI jank. Ensure the app maintains a steady 60fps/120fps.
- **Image & Asset Optimization:** Compress any bundled assets (icons, placeholder images) to reduce the final APK/IPA download size.
- **Database Tuning:** Verify that Drift SQLite indices are correctly configured. A local database with thousands of transactions must query and aggregate sums instantly without blocking the main thread.

### 3. Monitoring & Analytics (Optional but Recommended)
- **Crash Reporting:** Integrate Firebase Crashlytics or Sentry. While the app is local-first, capturing anonymous crash stacks is vital for fixing device-specific bugs in production.
- **Analytics:** (If approved by privacy policy) Implement basic anonymous telemetry to track which features (e.g., Budgets vs. Goals) are most used, helping guide future development.

### 4. Build Configuration & Obfuscation
- **Android ProGuard/R8:** Configure obfuscation to shrink the APK and protect the codebase against reverse engineering.
- **Environment Variables:** Ensure development/mock API keys (if any external services are ever added) are stripped, and the app uses a clean, production configuration.
- **App Signing:** 
  - Generate a secure Keystore for Android App Bundles (AAB).
  - Configure Apple Developer Certificates and Provisioning Profiles for iOS IPA generation.

### 5. Automated Deployment (Future Enhancement)
- **Fastlane:** Set up `fastlane` to automate the process of building, signing, and uploading binaries to Google Play Console and App Store Connect.

## Final Milestone
Upon the successful completion of these items, the **Follow My Life** application will be certified for its `v1.0.0` public release.
