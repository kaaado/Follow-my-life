# FINANCE UX & INTERACTION SPECIFICATION — FOLLOW MY LIFE

## 1. Home Command Center UX Hierarchy
1. **Header Greeting**: Personal welcome ("Good morning/afternoon/evening, [User]"), Profile Avatar, Quick Notification Bell.
2. **Total Balance Hero Card**:
   - High-contrast gradient background (Glassmorphic / Vibrant Dark gradient).
   - Displays **Total Balance** in clear monetary typography.
   - Sub-bars for **Available Balance** and **Reserved Balance**.
   - Tap interaction toggles expandable account breakdown (Cash, Bank, Wallet) inline with smooth curve transition.
3. **Financial Health Bar / Badges**:
   - **Safe-to-Spend Badge**: Indicates spending ceiling after reserved money and bills.
   - **Money Coming Badge**: Indicates expected incoming cash flow.
4. **Monthly Cash Flow Overview**:
   - Income, Expenses, Net Cash Flow indicator.
5. **Quick Action Grid**:
   - + Income (Green)
   - - Expense (Rose/Red)
   - ⇄ Transfer (Indigo/Blue)
   - 📋 Plan (Amber/Gold)
   - 📊 Reports (Purple)
6. **Upcoming Events Carousel/List**:
   - Shows due subscriptions, bills, and expected income.
7. **Recent Activity Stream**:
   - Date-grouped transaction cards with category icons, direction indicators, and amount styling.

---

## 2. Activity Tab & Filters UX
- Instant search by payee, description, or origin.
- Multi-faceted filter bar (Type: Income/Expense/Transfer, Account: All/Cash/Bank, Category, Date range).
- Grouped by Date Headers ("Today", "Yesterday", "August 24, 2026").
- Infinite scroll/pagination with skeleton loaders.

---

## 3. Financial Reports & Intelligence UX
- Visual Cash Flow trends (Area / Line charts).
- Interactive Category Donut / Pie charts with tap-to-highlight legend.
- Source distribution breakdown.
- Financial health score & actionable tips.
