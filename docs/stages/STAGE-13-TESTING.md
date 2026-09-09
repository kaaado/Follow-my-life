# STAGE 13 — Testing, Hardening & QA

## Objective
Establish a rigorous quality assurance baseline. Financial applications demand zero tolerance for data corruption, incorrect calculations, or unhandled crashes. This stage focuses on fortifying the application through comprehensive testing layers and defensive programming.

## Testing Strategy & Pyramid

### 1. Unit Testing (Core Logic & Data Layer)
- **Scope:** Repositories, Use Cases, Providers, and pure Dart utilities (calculations, string formatting, date parsing).
- **Tools:** `flutter_test`, `mockito` / `mocktail`.
- **Implementation Goals:**
  - Mock the `Drift` SQLite database to test Repository CRUD operations in isolation.
  - Test Riverpod `StateNotifier` or `AsyncNotifier` logic to ensure state transitions correctly under various simulated data loads.
  - Verify all math related to ledgers (e.g., ensuring `Income - Expense == Total Balance` handles floating point or integer cent conversions flawlessly).

### 2. Widget Testing (UI Component Isolation)
- **Scope:** Individual screens, forms, and custom components (`TransactionCard`, `AddMoneySourceForm`).
- **Tools:** `flutter_test`.
- **Implementation Goals:**
  - Verify that UI elements render correctly given a specific Riverpod state (using `ProviderScope` overrides).
  - Simulate user interactions (tapping buttons, entering text) to ensure forms validate correctly and trigger the appropriate state changes or provider calls.
  - Ensure Error states and Loading states (spinners/shimmers) appear as expected.

### 3. Integration Testing (End-to-End User Journeys)
- **Scope:** Full app flows running on emulators or real devices.
- **Tools:** `integration_test`.
- **Implementation Goals:**
  - Write complete E2E tests for the core loops: 
    1. App Boot -> Add Money Source -> Add Income -> Verify Dashboard Balance.
    2. Add Category -> Add Expense -> Check Budget Overrun.
  - Ensure database persistence behaves correctly across simulated app restarts.

## Hardening & Error Handling
- **Global Error Boundary:** 
  - Intercept uncaught Flutter framework exceptions via `FlutterError.onError`.
  - Intercept asynchronous Dart exceptions via `PlatformDispatcher.instance.onError`.
- **Defensive State Management:** 
  - Ensure all Riverpod providers gracefully handle `AsyncError` and display friendly, localized fallback UIs (e.g., "Unable to load transactions" rather than a red screen of death).
- **Database Migrations:** 
  - Ensure Drift `MigrationStrategy` is rock-solid. Testing schema upgrades from `v1` to `v2` without data loss will be a critical part of the hardening process before any app update.

## Continuous Integration (CI)
- Set up a basic CI pipeline (e.g., GitHub Actions) to run `flutter analyze` and `flutter test` automatically on every commit/PR to maintain code hygiene and prevent regressions.

## Next Stage
Proceed to **STAGE 14 — Production Readiness**.
