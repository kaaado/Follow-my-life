# STAGE 8 — Budgets

## Objective
Provide users with tools to limit their spending per category or generally over specific time periods (weekly, monthly, yearly).

## Implemented Features
- **Budgets Overview Screen (`BudgetsPage`):**
  - Displays active budgets with visual progress bars.
  - Progress bar colors change dynamically based on consumption (e.g., turns red if > 90% utilized).
- **Add Budget Screen (`AddBudgetPage`):**
  - Form to create a new budget constraint.
  - Supports linking to a specific expense category or keeping it general.
  - Allows selecting the period (Weekly, Monthly, Yearly).
- **Budget Repository (`BudgetRepository`):**
  - Methods to create and watch budgets.
  - Built the foundation for `updateBudgetSpent` which is intended to be called when an expense transaction is recorded.

## Architecture Decisions
- **Progress Tracking:** Budgets track `currentSpentMinor` against `limitAmountMinor` directly in the database. This avoids running heavy SUM queries across the entire transaction ledger every time the UI renders. It acts as a materialized view of the budget's status.

## Files Changed/Added
- `lib/features/finance/data/repositories/budget_repository.dart`
- `lib/features/finance/presentation/pages/budgets_page.dart`
- `lib/features/finance/presentation/pages/add_budget_page.dart`

## Next Stage
Proceed to **STAGE 9 — Recurring Money**.
