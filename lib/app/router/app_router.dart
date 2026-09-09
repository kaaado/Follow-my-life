/// GoRouter configuration with bottom navigation shell.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/features/onboarding/presentation/pages/splash_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/home_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/transactions_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/plan_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/sources_page.dart';
import 'package:follow_my_life/features/profile/presentation/pages/profile_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/add_expense_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/add_income_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/add_source_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/transfer_page.dart';
import 'package:follow_my_life/features/profile/presentation/pages/onboarding_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/add_purchase_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/categories_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/add_category_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/budgets_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/add_budget_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/recurring_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/add_recurring_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/transaction_detail_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/reports_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/debt_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/add_debt_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/forecast_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/calendar_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_my_life/features/finance/presentation/pages/monthly_review_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/virtual_splits_page.dart';
import 'package:follow_my_life/features/finance/presentation/pages/create_virtual_split_page.dart';
import 'package:follow_my_life/features/profile/presentation/pages/lock_page.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/widgets/app_empty_state.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';
import 'package:follow_my_life/core/security/security_service.dart';
import 'package:follow_my_life/core/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final security = ref.read(securityServiceProvider);
  return createRouter(security: security);
});

GoRouter createRouter({SecurityService? security}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: security,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: Text(context.tr('item_not_found')),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.go('/'),
        ),
      ),
      body: AppEmptyState(
        icon: LucideIcons.fileQuestion,
        title: context.tr('item_not_found'),
        message: context.tr('page_not_found_desc'),
        actionLabel: context.tr('home'),
        onAction: () => context.go('/'),
      ),
    ),
    redirect: (context, state) {
      final isLocked = security?.isLocked ?? false;
      final loc = state.uri.toString();

      if (isLocked) {
        if (loc != '/lock' && loc != '/splash' && loc != '/onboarding') {
          return '/lock';
        }
      } else {
        if (loc == '/lock') {
          return '/';
        }
      }
      return null;
    },
    routes: [
      // Lock screen
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockPage(),
      ),

      // Splash screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),

      // Main shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomePage(),
            ),
          ),
          GoRoute(
            path: '/transactions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TransactionsPage(),
            ),
          ),
          GoRoute(
            path: '/plan',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlanPage(),
            ),
          ),
          GoRoute(
            path: '/sources',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SourcesPage(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfilePage(),
            ),
          ),
        ],
      ),

      // Full-screen routes (above bottom nav)
      GoRoute(
        path: '/add-expense',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddExpensePage(),
      ),
      GoRoute(
        path: '/add-income',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddIncomePage(),
      ),
      GoRoute(
        path: '/add-source',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddSourcePage(),
      ),
      GoRoute(
        path: '/transfer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TransferPage(),
      ),
      GoRoute(
        path: '/add-purchase',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddPurchasePage(),
      ),
      GoRoute(
        path: '/categories',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: '/add-category',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddCategoryPage(),
      ),
      GoRoute(
        path: '/budgets',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BudgetsPage(),
      ),
      GoRoute(
        path: '/add-budget',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddBudgetPage(),
      ),
      GoRoute(
        path: '/recurring',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RecurringPage(),
      ),
      GoRoute(
        path: '/add-recurring',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddRecurringPage(),
      ),
      GoRoute(
        path: '/transaction-detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TransactionDetailPage(
          transactionId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/transaction/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TransactionDetailPage(
          transactionId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/transaction/detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TransactionDetailPage(
          transactionId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/transactions/detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TransactionDetailPage(
          transactionId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportsPage(),
      ),
      GoRoute(
        path: '/debts',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DebtPage(),
      ),
      GoRoute(
        path: '/add-debt',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddDebtPage(),
      ),
      GoRoute(
        path: '/forecast',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ForecastPage(),
      ),
      GoRoute(
        path: '/calendar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CalendarPage(),
      ),
      GoRoute(
        path: '/monthly-review',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MonthlyReviewPage(),
      ),
      GoRoute(
        path: '/virtual-splits',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VirtualSplitsPage(),
      ),
      GoRoute(
        path: '/create-virtual-split',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateVirtualSplitPage(),
      ),
    ],
  );
}
