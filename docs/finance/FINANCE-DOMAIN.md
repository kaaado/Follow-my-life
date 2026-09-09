# FINANCIAL DOMAIN SPECIFICATION — FOLLOW MY LIFE

## 1. Core Domain Separation Matrix

In Follow My Life, financial concepts are strictly segregated into distinct domain dimensions:

| Dimension | Concept | Examples | Role in Application |
|---|---|---|---|
| **Money Location / Account** | Physical/digital account where funds reside | Cash, Bank Account, BaridiMob, Wallet, Savings | Affects actual balance and account reconciliation |
| **Income Source / Origin** | Origin or reason why money was received | Salary, Freelance, Sold Phone, Business, Gift, Refund | Answers "Where did this money come from?" |
| **Expense Destination / Payee** | Vendor, merchant, or individual receiving payment | Restaurant, Transport, Pharmacy, Supermarket, Bill | Answers "Where did the money go?" |
| **Category** | Classification of spending or earning | Food, Transport, Health, Housing, Education, Savings | Used for budgeting, analytics, and spending breakdown |
| **Plan** | Future purchase or financial goal intention | Buy Laptop, Travel Fund, Emergency Fund, Education | Tracks estimated amount, saved amount, priority, and status |
| **Recurring Event** | Scheduled, automated financial occurrence | Monthly Salary, Rent, Internet Subscription, Allowance | Idempotently generates transactions according to schedule |

---

## 2. Reconciled Accounting Formula
The system maintains strict mathematical reconciliation across all calculations:

$$\text{Total Balance} = \sum_{s \in \text{Active Money Sources}} \text{Balance}(s)$$

$$\text{Total Balance} = \text{Available Balance} + \text{Reserved Balance}$$

$$\text{Safe-to-Spend} = \text{Available Balance} - \text{Reserved Money} - \text{Upcoming Mandatory Expenses}$$

$$\text{Net Cash Flow} = \text{Total Income} - \text{Total Expenses}$$

---

## 3. Financial Integrity & Idempotency Rules
1. **No Silent Mutations**: Balance changes MUST only occur through explicit atomic transactions logged in the database.
2. **Idempotent Recurring Execution**: Every recurring event occurrence is assigned a unique occurrence identity (`RecurringOccurrences`). App restarts or background syncs will never execute the same occurrence twice.
3. **Multi-Currency Display Guarantee**: Changing default currency alters UI formatting without silently mutating stored raw minor values.
4. **Reversal Audit**: Correcting or deleting transactions updates cached source balances using exact atomic operations.
