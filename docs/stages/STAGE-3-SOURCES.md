# STAGE 3 — Money Sources

## Objective
Enable users to create, view, and manage multiple money sources (wallets, bank accounts, etc.), providing the foundational buckets for the transaction engine.

## Implemented Features
- **Sources Overview Screen (`SourcesPage`):**
  - Displays total balance across all active sources.
  - Lists individual sources with their specific balances, icons, and colors.
  - Implemented staggered fade-in animations for a premium feel.
- **Add Source Screen (`AddSourcePage`):**
  - Form to create a new source.
  - Captures Name, Type (Cash, Bank, E-Wallet, etc.), and Initial Balance.
  - Horizontal selectors for choosing an Icon and Color index.
  - Real-time validation and error handling using SnackBar.
- **Drift Integration:**
  - Used `SourceRepository` to persist new sources.
  - Automatically recalculates balances and total wealth across the app using `Riverpod` reactive streams.

## Architecture Decisions
- **Cached Balances:** To avoid querying the entire transaction ledger on every frame, `MoneySources` has a `cachedBalanceMinor` field. This acts as the immediate read-model for the UI, while the transaction ledger remains the true source of truth.
- **Minor Units:** The initial balance input is parsed into minor units (e.g., centimes) before database insertion to guarantee precision.

## Files Changed/Added
- `lib/features/finance/presentation/pages/sources_page.dart`
- `lib/features/finance/presentation/pages/add_source_page.dart`

## Next Stage
Proceed to **STAGE 4 — Transaction Engine**.
