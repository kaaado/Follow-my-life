# STAGE 7 — Purchase Planning

## Objective
Implement a system to allow users to plan and track future purchases. This includes prioritizing purchases and converting them into actual transactions once the user commits to buying them.

## Implemented Features
- **Purchase Planning Screen (`PlanPage`):**
  - Displays all active planned purchases.
  - Calculates and displays the total estimated cost of all planned items.
  - Purchases are marked with priority colors (High: Red, Medium: Yellow/Tertiary, Low: Primary).
  - Empty state with a call-to-action for the first planned purchase.
- **Add Purchase Screen (`AddPurchasePage`):**
  - Form to create a new planned purchase.
  - Inputs: Item Name, Estimated Cost, Priority (Low/Medium/High), and an optional Target Date via DatePicker.
- **Purchase Repository (`PurchaseRepository`):**
  - Handles CRUD operations for `PlannedPurchases`.
  - Implements the critical `markAsPurchased` function using an atomic Drift database transaction:
    1. Validates that the selected money source has sufficient funds.
    2. Creates an `expense` transaction linking to the purchase.
    3. Deducts the actual purchase amount from the money source's cached balance.
    4. Updates the planned purchase status from `planned` to `purchased`.
- **Riverpod Providers:**
  - Added `purchaseRepositoryProvider`.
  - Added `activePurchasesProvider` stream to keep the `PlanPage` updated in real-time.

## Architecture Decisions
- **Decoupled Planning vs. Execution:** A planned purchase does not affect balances until the user explicitly completes it via `markAsPurchased`. This prevents "ghost" money from affecting the user's perception of their current available cash.
- **Linked Records:** When a purchase is completed, the resulting transaction holds a `referenceId` pointing back to the purchase, allowing the UI to link the history together.

## Files Changed/Added
- `lib/features/finance/data/repositories/purchase_repository.dart`
- `lib/features/finance/application/providers/finance_providers.dart` (Updated)
- `lib/features/finance/presentation/pages/plan_page.dart`
- `lib/features/finance/presentation/pages/add_purchase_page.dart`
- `lib/app/router/app_router.dart` (Updated)

## Known Limitations
- The "mark as purchased" UI dialogue / bottom sheet on the `PlanPage` is currently a placeholder comment (`// TODO: Show complete purchase dialog`). The underlying data layer supports it fully.

## Next Stage
Proceed to **STAGE 8 & 9 — Budgets and Recurring Money**.
