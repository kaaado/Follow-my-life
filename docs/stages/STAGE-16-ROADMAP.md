# STAGE 16 — FINTECH MASTER ROADMAP

## Phased Implementation Plan

### Phase 1: Debt & Loan Management System
- **Objective**: Track money owed by the user ("I Owe") and money owed to the user ("Owed to Me").
- **Database Schema**: Create `Debts` table in Drift with status (`active`, `partially_paid`, `paid`, `overdue`), counterparty person name, principal amount, paid amount, due date, interest/notes.
- **UI & Navigation**: Add `DebtPage`, `AddDebtPage`, and `RecordDebtPaymentPage`.
- **Integrations**: Recording a debt repayment automatically creates a corresponding transaction and updates the money source balance.

### Phase 2: Split Transactions & Linked Refunds
- **Objective**: Support multi-category itemization for single transactions and linked expense refunds.
- **Database Schema**: Add `SplitTransactions` table (or JSON details) and `refundTransactionId` on `Transactions`.
- **UI & Navigation**: Add Split Transaction input option in `AddExpensePage` and "Record Refund" option on `TransactionDetailPage`.

### Phase 3: Financial Health, Cash-Flow Forecast & Calendar Engine
- **Objective**: Provide projection engines (7d, 30d, 3m, 6m, 1y) and visual financial timeline.
- **Services**: Implement `FinancialHealthService`, `ForecastService`.
- **UI & Navigation**: Add `CalendarPage` and `ForecastPage` / `FinancialHealthCard`.

### Phase 4: Sinking Funds & Emergency Reserve Architecture
- **Objective**: Distinguish between target goals, predictable annual/periodic sinking funds, and emergency safety reserves.
- **UI & Navigation**: Enhance `PlanPage` & `GoalsPage` with emergency fund target progress sliders and sinking fund schedules.

### Phase 5: Net Worth Analytics & Monthly Financial Review
- **Objective**: Aggregate total assets (cash + bank + wallet + receivables) minus liabilities (debts/loans) to present Net Worth.
- **UI & Navigation**: Add `NetWorthCard` and `MonthlyReviewPage` summarizing monthly performance.

### Phase 6: Complete Localization (EN, FR, AR + RTL/LTR) & Theme System Polish
- **Objective**: 100% string coverage across English, French, and Arabic. Audit RTL layout direction, date/currency formatting, and high-contrast Light/Dark theme rendering.

### Phase 7: Security & Backup Hardening
- **Objective**: Enforce background PIN/Biometric auto-lock timeouts and password-protected JSON backup/restore with integrity checks.
