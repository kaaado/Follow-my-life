# FINANCIAL MODEL & DOMAIN CONCEPTS

## 1. Core Abstractions

### Money & Precise Representation
All monetary balances and amounts in **Follow My Life** are stored as 64-bit integers representing minor units (cents / centimes) to avoid IEEE-754 binary floating-point representation errors.
Example: `10,500.50 DZD` is stored internally as `1050050`.

### Money Locations (Accounts)
An Account / Money Source represents where liquid cash or digital funds physically reside:
- **Cash**: Wallet, physical safe.
- **Bank**: Checking account, savings account.
- **Digital Wallet**: Mobile payment app, card balance.

### Financial State Taxonomy
- **ACTUAL**: Realized, historical balances and transactions.
- **EXPECTED**: Guaranteed or projected future income (e.g. salary).
- **PLANNED**: Intended allocations for future purchases or goals.
- **RESERVED**: Locked funds earmarked for specific goals/commitments, subtracted from discretionary balance.
- **PROJECTED**: Expected balance trajectories over 7d, 30d, 90d, 180d, 365d horizons.

### Debts & Obligations
- **I Owe**: Liabilities (money borrowed, bank installment, un-paid bill).
- **Owed to Me**: Receivables (money lent to a friend or client).
- Repayments update both the debt status and account balance atomically.

### Transfers
Internal movements of value between two owned accounts. Transfers do not change net worth or count as income/expense.
