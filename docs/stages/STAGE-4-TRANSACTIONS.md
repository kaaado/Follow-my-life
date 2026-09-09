# STAGE 4 — Transaction Engine

## Objective
Implement the core financial ledger, allowing users to record income, expenses, and transfers with strict database constraints and reactive UI updates.

## Implemented Features
- **Add Income (`AddIncomePage`):**
  - Form to add incoming money.
  - Requires selecting a destination Source.
  - Auto-updates the selected source's balance upon completion.
- **Add Expense (`AddExpensePage`):**
  - Form to record spending.
  - Includes Category selection (dynamically loaded from DB).
  - Validation: Prevents spending if the selected source lacks sufficient funds (handled by `TransactionRepository` returning `InsufficientFundsFailure`).
- **Transfer Money (`TransferPage`):**
  - Form to move money between two distinct sources.
  - Validation: Cannot transfer from A to A. Validates sufficient funds in source A.
- **Transactions History (`TransactionsPage`):**
  - Displays a chronologically sorted list of all ledger events.
  - Built-in horizontal filter chips (All, Income, Expense, Transfer).
  - Uses dynamic icons and colors based on transaction type.
- **Dashboard Integration (`HomePage`):**
  - Linked the "Recent Activity" widget to the actual transaction stream.
  - Linked "This Month" summary (Total Income / Total Expenses) to dynamic calculations from the ledger.
  - Connected Quick Action buttons to their respective screens.

## Architecture Decisions
- **Atomic Operations:** All money movements (`recordExpense`, `recordIncome`, `recordTransfer`) wrap database inserts and balance cache updates inside a `_db.transaction()`. If the balance update fails, the ledger entry is rolled back.
- **Sealed Results:** The UI relies entirely on `.when()` matching of the `Result<T>` type to determine if a form submission should navigate back or show a SnackBar error. No bare `try/catch` blocks leak into the UI presentation layer.

## Files Changed/Added
- `lib/features/finance/presentation/pages/add_income_page.dart`
- `lib/features/finance/presentation/pages/add_expense_page.dart`
- `lib/features/finance/presentation/pages/transfer_page.dart`
- `lib/features/finance/presentation/pages/transactions_page.dart`
- `lib/features/finance/presentation/pages/home_page.dart` (Updated)

## Known Limitations
- Categories are currently static (seeded in Stage 1) and cannot yet be managed by the user.

## Next Stage
Proceed to **STAGE 5 & 6 — Categories & Allocations** (and Purchase Planning).
