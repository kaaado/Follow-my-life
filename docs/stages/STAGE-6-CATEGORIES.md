# STAGE 6 — Categories & Allocations

## Objective
Provide the ability to organize and tag financial transactions effectively. Allow users to add custom categories beyond the default seeded ones.

## Implemented Features
- **Categories Management Screen (`CategoriesPage`):**
  - Displays all active categories split by type (Income vs Expense).
  - Shows custom colors and icons for each category.
- **Add Category Screen (`AddCategoryPage`):**
  - Form to create custom categories.
  - Users can select the name, type (Expense/Income), and assign a color index.
- **Integration:**
  - `ProfilePage` updated to include a "Manage Categories" shortcut.
  - Dropdown in `AddExpensePage` automatically watches the `activeCategoriesProvider` to reflect newly added categories immediately.

## Architecture Decisions
- **Color/Icon Indexes:** Instead of storing complex styling data in SQLite, we store simple integer indexes or string keys (e.g., `colorIndex: 0`, `icon: 'tag'`). The UI layer translates these into actual `Color` objects and `IconData` (via `AppColors.getCategoryColor()`), keeping the domain model clean and decoupled from Flutter.

## Files Changed/Added
- `lib/features/finance/presentation/pages/categories_page.dart`
- `lib/features/finance/presentation/pages/add_category_page.dart`
- `lib/features/profile/presentation/pages/profile_page.dart` (Updated)
- `lib/app/router/app_router.dart` (Updated)

## Known Limitations
- "Allocations" (splitting a single transaction across multiple categories) is not yet implemented. The foundation supports 1-to-1 Category-to-Transaction mapping.

## Next Stage
Proceed to **STAGE 7 — Purchase Planning**.
