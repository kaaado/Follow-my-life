# STAGE 5 — Dashboard

## Objective
Create a unified home view summarizing the user's financial life, integrating all the individual modules (Sources, Transactions, etc.) into a cohesive, high-performance UI.

## Implemented Features
- **Total Balance Hero Card:** Consolidates wealth across all active money sources. Includes visual indicators for "Available" vs "Reserved" funds (reserved funds to be fully utilized in Stage 8 - Budgets).
- **Monthly Summary:** Real-time aggregation of income and expenses for the current month. Uses `Riverpod` streams to instantly reflect any new transactions.
- **Quick Actions:** High-visibility shortcuts to `Add Income`, `Add Expense`, `Transfer`, and `Plan Purchase`.
- **Recent Activity:** A condensed list of the 5 most recent transactions, with dynamic iconography based on category/type.

## Architecture Decisions
- **Sliver Architecture:** The `HomePage` utilizes `CustomScrollView` and Slivers (`SliverAppBar`, `SliverList`) to achieve smooth scrolling and a collapsible header for a premium feel.
- **Reactive Aggregation:** Instead of querying the database manually on `build`, the Dashboard watches several `StreamProvider`s. When an expense is added, the `totalBalanceProvider`, `monthSummaryProvider`, and `recentTransactionsProvider` all emit new states automatically, hydrating the UI without imperative reload calls.

## Files Changed/Added
- `lib/features/finance/presentation/pages/home_page.dart`
- `lib/features/finance/application/providers/finance_providers.dart` (Queries for aggregations)

## Next Stage
Proceed to **STAGE 6 — Categories & Allocations**.
