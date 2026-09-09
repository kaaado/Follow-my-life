# VIRTUAL SPLIT SYSTEM SPECIFICATION

## 1. CONCEPT OVERVIEW
The **Virtual Split System** is a planning and financial reservation layer. It allows users to reserve/allocate portions of their total available balance across target categories or custom spending goals (e.g., Food: 2,000 DZD, Transport: 1,000 DZD) **without** immediately creating actual expenses or reducing their true bank balance.

---

## 2. KEY PRINCIPLES
1. **Virtual Reservation != Actual Expense:**
   Creating a virtual split does NOT change the total balance displayed on the Home Dashboard.
2. **State Machine:**
   `DRAFT` -> `ACTIVE` -> `APPLYING` -> `APPLIED` (or `CANCELLED` / `FAILED`).
3. **Atomic Commit:**
   When a user clicks **APPLY SPLIT**, the virtual split is committed inside an isolated database transaction (`db.transaction(...)`).
4. **Concurrency & Double-Spending Protection:**
   - Database check verifies available funds prior to commit.
   - Idempotency check prevents re-applying an already applied split session.
   - Mutex locks concurrent apply attempts.

---

## 3. DATABASE SCHEMA

```sql
CREATE TABLE virtual_splits (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  source_id TEXT REFERENCES money_sources(id),
  total_amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'DZD',
  status TEXT NOT NULL DEFAULT 'active', -- draft, active, applying, applied, cancelled, failed
  applied_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE virtual_split_items (
  id TEXT NOT NULL PRIMARY KEY,
  split_id TEXT NOT NULL REFERENCES virtual_splits(id) ON DELETE CASCADE,
  category_id TEXT NOT NULL REFERENCES categories(id),
  amount_minor INTEGER NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL
);
```
