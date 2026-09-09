# STAGE 9 — Upcoming & Recurring Money

## Objective
Allow users to define recurring transactions (e.g., salaries, subscriptions) that the app can anticipate and automatically record or prompt for.

## Implemented Features
- **Recurring Overview Screen (`RecurringPage`):**
  - Lists all active recurring income and expense items.
  - Displays the next execution date and frequency.
- **Add Recurring Screen (`AddRecurringPage`):**
  - Form with segmented buttons to toggle between Income and Expense.
  - Frequency selection (Daily, Weekly, Monthly, Yearly).
  - Optional linkage to an auto-post Source and Category.
- **Recurring Repository (`RecurringRepository`):**
  - Handles the creation of `RecurringTransactions` in the Drift database.
  - Established a placeholder `executeDueTransactions()` method designed to be called by a background worker or upon app startup.

## Architecture Decisions
- **Background Execution Placeholder:** While the CRUD operations for recurring items are complete, automatically generating transactions based on these rules requires a reliable background job dispatcher (e.g., `workmanager`) or a robust startup check. The architecture is prepared for this via the repository pattern, isolating the business logic from the UI.

## Files Changed/Added
- `lib/features/finance/data/repositories/recurring_repository.dart`
- `lib/features/finance/presentation/pages/recurring_page.dart`
- `lib/features/finance/presentation/pages/add_recurring_page.dart`

## Next Stage
Proceed to **STAGE 10 & 11 — Backup & Security**.
