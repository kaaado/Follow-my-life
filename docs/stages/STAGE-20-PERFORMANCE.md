# STAGE 20 — PERFORMANCE & DATABASE OPTIMIZATION

## 1. Index Optimization
Compound indexes were added to SQLite via Drift table declarations to accelerate lookups on frequently queried fields:

| Table | Index Name | Indexed Columns | Query Purpose |
|---|---|---|---|
| `Transactions` | `idx_txn_date` | `date` | Rapid date-range aggregation & monthly filtering |
| `Transactions` | `idx_txn_source` | `source_id` | Account balance reconciliation |
| `Transactions` | `idx_txn_category` | `category_id` | Category budget tracking |
| `Budgets` | `idx_budget_cat_year_month` | `category_id, year, month` | Monthly category spending calculation |
| `RecurringTransactions` | `idx_rec_next` | `next_occurrence` | Automated recurring transaction scheduler |

## 2. State & Rebuild Optimization
- Riverpod `AsyncValue` watch calls are scoped to specific page widgets to eliminate unnecessary widget sub-tree re-renders.
- Expanded account details use `AnimatedCrossFade` to prevent layout reflow glitches.
