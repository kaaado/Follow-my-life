# STAGE 18 — IMPLEMENTATION ROADMAP & ARCHITECTURE SPECIFICATION
**Project:** Follow My Life  
**Focus:** Senior FinTech Engineering, Virtual Splits, Plan Intelligence, Biometrics, Security, Performance & Full Localization  

---

## 1. PHASES AND OBJECTIVES

### PHASE 1: Audit & Repository Foundation
- Complete exhaustive audit of architecture, schemas, localization, performance, and security.
- Generate full stage documentation in `docs/stages/` and `docs/finance/`.

### PHASE 2: Complete Localization Architecture (EN, FR, AR)
- Centralize all keys in `AppLocalizations`.
- Add missing keys for Virtual Splits, Multi-Plan Intelligence, Security, Biometrics, Debts, Budgets, Reports, and Notifications.
- Eliminate all hardcoded UI strings.

### PHASE 3: Complete RTL/LTR Layout Support
- Ensure Arabic locale uses `TextDirection.rtl` cleanly across all pages, app bars, cards, tabs, and bottom navigation.
- Replace directional hardcoding with `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end`, and directional chevrons.

### PHASE 4: Robust Security System (PIN & Biometrics)
- Add `local_auth` dependency to `pubspec.yaml`.
- Update Android `MainActivity.kt` to extend `FlutterFragmentActivity` and add biometric permissions to `AndroidManifest.xml`.
- Update iOS `Info.plist` with `NSFaceIDUsageDescription`.
- Store PIN securely using `FlutterSecureStorage` with SHA-256 key stretching/hashing.
- Build dedicated `LockPage` overlay triggerable on startup or after background auto-lock timeout.

### PHASE 5: Visual Design System & Themes
- Refine light, dark, and system themes in `AppTheme`.
- Centralize typography (`AppTypography`), colors (`AppColors`), spacing (`AppSpacing`), glassmorphism (`GlassCard`), and skeleton loading (`AppSkeleton`).

### PHASE 6: Database & Performance Optimization
- Optimize SQLite DAOs with SQL aggregation queries (`SUM`, `COUNT`) for balance calculations.
- Reduce Riverpod provider rebuild scope using `select()`.
- Add skeleton loading to Home, Transactions, Plans, Virtual Splits, Sources, and Reports.

### PHASE 7 & 8: Multi-Plan Architecture & Financial Intelligence
- Upgrade `PlannedPurchases` schema/repository to support plan priority, status (`Draft`, `Active`, `Paused`, `Completed`, `Cancelled`), target date, and contributions.
- Build `PlanIntelligenceService` to calculate:
  - Required monthly/weekly contributions
  - Expected completion date
  - Feasibility score
  - Multi-plan fund allocation recommendations & priority conflict alerts.

### PHASE 9, 10 & 11: Virtual Split System
- Define Drift tables: `VirtualSplits`, `VirtualSplitItems`, `SplitApplications`.
- Implement `VirtualSplitRepository` with atomic database transactions:
  - Validates available source balance.
  - State machine: `DRAFT` -> `ACTIVE` -> `APPLYING` -> `APPLIED` (or `FAILED`/`CANCELLED`).
  - Transactional commit: Creates expense/reservation records and updates split status atomically.
  - Idempotency & Mutex protection against double application or race conditions.
- Build dedicated Virtual Split UI page (`VirtualSplitPage`) accessible from Home and Navigation.

### PHASE 12 & 13: Reports, Analytics & Home Dashboard Polish
- Enhance charts (Cash Flow, Balance Trend, Category Breakdown, Budget Performance, Plan Progress) with fl_chart.
- Add deterministic financial insights to Home dashboard and Reports.

### PHASE 14 & 15: Activity, Sources, Budgets, Security & Full QA Testing
- Comprehensive unit tests for:
  - Split concurrency & atomic application failure recovery.
  - Plan intelligence calculations.
  - Security PIN hashing and validation logic.
  - Multi-language localization dictionary lookup.
