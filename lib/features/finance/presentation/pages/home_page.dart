import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_theme_presets.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/utils/date_helper.dart';
import 'package:follow_my_life/core/widgets/glass_card.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/features/finance/domain/services/safe_to_spend_service.dart';
import 'package:follow_my_life/features/finance/domain/services/smart_action_service.dart';
import 'package:follow_my_life/features/finance/domain/services/subscription_intelligence_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isBalanceExpanded = false;
  bool _hideAmounts = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final summaryAsync = ref.watch(financialSummaryProvider);
    final sourcesAsync = ref.watch(activeSourcesProvider);
    final presetId = ref.watch(appColorPresetProvider);
    final activePreset = AppThemePresets.getById(presetId);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = profileAsync.valueOrNull;
    final currency = profile?.currency ?? 'DZD';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: CustomScrollView(
        slivers: [
          // Elegant Header Bar
          SliverAppBar(
            expandedHeight: 110,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? AppColors.darkBg.withValues(alpha: 0.95) : AppColors.lightBg.withValues(alpha: 0.95),
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.md,
              ),
              title: profileAsync.when(
                data: (profile) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateHelper.greetingMessage(context),
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile?.name ?? context.tr('default_user'),
                          style: AppTypography.headlineMedium(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Toggle hide amounts
                        IconButton(
                          icon: Icon(
                            _hideAmounts ? LucideIcons.eyeOff : LucideIcons.eye,
                            size: 20,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _hideAmounts = !_hideAmounts;
                            });
                          },
                          tooltip: context.tr('toggle_balance_privacy'),
                        ),
                        const SizedBox(width: 4),
                        // Avatar Badge
                        GestureDetector(
                          onTap: () => context.go('/profile'),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: activePreset.gradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (profile?.name ?? 'U').substring(0, 1).toUpperCase(),
                                style: AppTypography.labelMedium(color: Colors.white)
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
              centerTitle: false,
            ),
          ),

          // Main Scroll View
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSpacing.sm),

                // Smart Assistant Actions
                _buildSmartActionCenter(context),
                
                // Hero Total Balance Card
                _buildTotalBalanceHeroCard(context, summaryAsync, sourcesAsync, currency, activePreset, primaryColor),

                const SizedBox(height: AppSpacing.lg),

                // Financial Badges (Safe to Spend & Daily Budget)
                _buildFinancialHealthBadges(context, summaryAsync, currency),

                const SizedBox(height: AppSpacing.xl),

                // Quick Action Buttons
                _buildQuickActions(context),

                const SizedBox(height: AppSpacing.xxl),

                // Monthly Summary Card
                _buildSectionHeader(context, context.tr('this_month'), context.tr('reports'), onTap: () => context.push('/reports')),
                const SizedBox(height: AppSpacing.md),
                _buildMonthlySummary(context, summaryAsync, currency),

                const SizedBox(height: AppSpacing.xxl),

                // Upcoming Events
                _buildUpcomingEventsSection(context, currency),

                const SizedBox(height: AppSpacing.xxl),

                // Recent Activity
                _buildSectionHeader(context, context.tr('recent_activity'), context.tr('view_all'), onTap: () => context.go('/transactions')),
                const SizedBox(height: AppSpacing.md),
                _buildRecentTransactions(context, currency),
                
                const SizedBox(height: AppSpacing.xxxl * 2),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceHeroCard(
    BuildContext context,
    AsyncValue summaryAsync,
    AsyncValue<List<MoneySource>> sourcesAsync,
    String currency,
    AppThemePreset activePreset,
    Color primaryColor,
  ) {
    final sources = sourcesAsync.valueOrNull ?? [];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _isBalanceExpanded = !_isBalanceExpanded;
            });
          },
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: HeroCard(
            gradient: activePreset.gradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.tr('total_balance').toUpperCase(),
                          style: AppTypography.labelMedium(color: Colors.white.withValues(alpha: 0.85))
                              .copyWith(letterSpacing: 1.1),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: _isBalanceExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            LucideIcons.chevronDown,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.wallet, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            '${sources.length} ${context.tr('accounts')}',
                            style: AppTypography.labelSmall(color: Colors.white)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Total Amount Display
                summaryAsync.when(
                  data: (summary) => Text(
                    _hideAmounts ? '••••••••' : MoneyFormatter.format(summary.totalBalance, currency: currency),
                    style: AppTypography.moneyLarge(color: Colors.white).copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: _hideAmounts ? 3 : -0.5,
                    ),
                  ),
                  loading: () => Text(
                    '...',
                    style: AppTypography.moneyLarge(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  error: (err, stack) => Text(
                    context.tr('something_went_wrong'),
                    style: AppTypography.moneyLarge(color: Colors.white),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Available vs Reserved Sub-Balances
                summaryAsync.maybeWhen(
                  data: (summary) => Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSubBalance(
                            title: context.tr('available_balance'),
                            amount: summary.availableBalance,
                            currency: currency,
                            icon: LucideIcons.checkCircle2,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.md),
                            child: _buildSubBalance(
                              title: context.tr('reserved_balance'),
                              amount: summary.reservedBalance,
                              currency: currency,
                              icon: LucideIcons.lock,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),

                // Animated Expandable Account Breakdown List
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      Divider(color: Colors.white.withValues(alpha: 0.25), height: 1),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('money_locations').toUpperCase(),
                            style: AppTypography.labelSmall(color: Colors.white.withValues(alpha: 0.75)),
                          ),
                          Text(
                            context.tr('reconciled').toUpperCase(),
                            style: AppTypography.labelSmall(color: Colors.white.withValues(alpha: 0.75)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...sources.map((source) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getSourceIcon(source.type.name),
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    source.name,
                                    style: AppTypography.bodySmall(color: Colors.white)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  _hideAmounts
                                      ? '••••'
                                      : MoneyFormatter.format(source.cachedBalanceMinor, currency: source.currency),
                                  style: AppTypography.bodySmall(color: Colors.white)
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                  crossFadeState: _isBalanceExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubBalance({
    required String title,
    required int amount,
    required String currency,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 4),
            Text(
              title,
              style: AppTypography.labelSmall(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _hideAmounts ? '••••••' : MoneyFormatter.format(amount, currency: currency),
          style: AppTypography.bodyLarge(color: Colors.white).copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: _hideAmounts ? 2 : 0,
          ),
        ),
      ],
    );
  }

  IconData _getSourceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return LucideIcons.building2;
      case 'card':
      case 'baridimob':
        return LucideIcons.creditCard;
      case 'savings':
        return LucideIcons.piggyBank;
      default:
        return LucideIcons.banknote;
    }
  }

  Widget _buildSmartActionCenter(BuildContext context) {
    final snapshotAsync = ref.watch(financialSnapshotProvider);
    final summary = ref.watch(financialSummaryProvider).valueOrNull;
    final recurring = ref.watch(activeRecurringProvider).valueOrNull ?? [];
    final subSummary = SubscriptionIntelligenceService.analyze(
      recurringTxns: recurring,
      monthlyIncomeMinor: summary?.totalIncome ?? 0,
    );

    return snapshotAsync.maybeWhen(
      data: (snapshot) {
        final actions = SmartActionService.generateActions(
          snapshot: snapshot,
          anomalies: [],
          subscriptionSummary: subSummary,
        );

        if (actions.isEmpty) return const SizedBox.shrink();

        final topAction = actions.first;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        Color actionColor;
        IconData actionIcon;
        switch (topAction.priority) {
          case ActionPriority.critical:
            actionColor = AppColors.error;
            actionIcon = LucideIcons.alertTriangle;
            break;
          case ActionPriority.important:
            actionColor = AppColors.warning;
            actionIcon = LucideIcons.bell;
            break;
          case ActionPriority.recommended:
            actionColor = Theme.of(context).colorScheme.primary;
            actionIcon = LucideIcons.sparkles;
            break;
          case ActionPriority.optional:
            actionColor = AppColors.info;
            actionIcon = LucideIcons.info;
            break;
        }

        final title = topAction.directTitle ?? (topAction.titleKey.isNotEmpty ? context.tr(topAction.titleKey) : context.tr('smart_recommendation'));
        final description = topAction.directDescription ?? (topAction.descriptionKey.isNotEmpty ? context.tr(topAction.descriptionKey) : '');

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: actionColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  colors: [
                    actionColor.withValues(alpha: isDark ? 0.20 : 0.12),
                    isDark ? AppColors.darkCard : AppColors.lightCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: actionColor.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(actionIcon, color: actionColor, size: 20),
                ),
                title: Text(
                  title,
                  style: AppTypography.bodyMedium(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  description,
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ElevatedButton(
                  onPressed: () => context.push(topAction.routeName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                  ),
                  child: Text(
                    context.tr('view'),
                    style: AppTypography.labelSmall(color: Colors.white)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _showSafeToSpendExplanationDialog(BuildContext context, String currency) {
    final sources = ref.read(activeSourcesProvider).valueOrNull ?? [];
    final plans = ref.read(activePurchasesProvider).valueOrNull ?? [];
    final splitsWithItems = ref.read(activeVirtualSplitsProvider).valueOrNull ?? [];
    final splits = splitsWithItems.map((s) => s.split).toList();
    final recurring = ref.read(activeRecurringProvider).valueOrNull ?? [];
    final debts = ref.read(activeDebtsProvider).valueOrNull ?? [];

    final breakdown = SafeToSpendService.calculate(
      sources: sources,
      plans: plans,
      virtualSplits: splits,
      recurringItems: recurring,
      debts: debts,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.shieldCheck, color: AppColors.income, size: 24),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  context.tr('safe_to_spend_breakdown'),
                  style: AppTypography.headlineMedium(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr('safe_to_spend_desc'),
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            ...breakdown.lineItems.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        '${item.isAddition ? '+' : '-'}${MoneyFormatter.format(item.amountMinor, currency: currency)}',
                        style: AppTypography.bodyMedium(
                          color: item.isAddition ? AppColors.income : AppColors.expense,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.income.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('safe_to_spend_today'),
                    style: AppTypography.labelMedium(color: AppColors.income),
                  ),
                  Text(
                    MoneyFormatter.format(breakdown.safeToSpendMinor, currency: currency),
                    style: AppTypography.headlineMedium(color: AppColors.income),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialHealthBadges(
    BuildContext context,
    AsyncValue summaryAsync,
    String currency,
  ) {
    final snapshotAsync = ref.watch(financialSnapshotProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Row(
          children: [
            // Safe to Spend Badge
            Expanded(
              child: InkWell(
                onTap: () => _showSafeToSpendExplanationDialog(context, currency),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.shieldCheck, color: AppColors.income, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  context.tr('safe_to_spend'),
                                  style: AppTypography.labelSmall(color: AppColors.income)
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 3),
                                const Icon(LucideIcons.info, size: 11, color: AppColors.income),
                              ],
                            ),
                            const SizedBox(height: 2),
                            summaryAsync.maybeWhen(
                              data: (summary) => Text(
                                _hideAmounts
                                    ? '••••••'
                                    : MoneyFormatter.formatNumber(summary.safeToSpend, currency: currency),
                                style: AppTypography.bodyMedium(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              orElse: () => const Text('...'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Daily Budget Badge
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.calendarDays, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          snapshotAsync.maybeWhen(
                            data: (snap) => Text(
                              '${snap.daysLeftInMonth} ${context.tr('days_left')}',
                              style: AppTypography.labelSmall(color: primaryColor)
                                  .copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            orElse: () => Text(
                              context.tr('daily_budget'),
                              style: AppTypography.labelSmall(color: primaryColor),
                            ),
                          ),
                          const SizedBox(height: 2),
                          snapshotAsync.maybeWhen(
                            data: (snap) => Text(
                              _hideAmounts
                                  ? '••••/d'
                                  : '${MoneyFormatter.formatNumber(snap.dailyBudgetMinor, currency: currency)}/d',
                              style: AppTypography.bodyMedium(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ).copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            orElse: () => const Text('...'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildActionBtn(context, context.tr('income'), LucideIcons.arrowDownToLine, AppColors.income, () => context.push('/add-income'))),
        Expanded(child: _buildActionBtn(context, context.tr('expense'), LucideIcons.arrowUpFromLine, AppColors.expense, () => context.push('/add-expense'))),
        Expanded(child: _buildActionBtn(context, context.tr('transfer'), LucideIcons.arrowRightLeft, AppColors.transfer, () => context.push('/transfer'))),
        Expanded(child: _buildActionBtn(context, context.tr('plan'), LucideIcons.clipboardList, AppColors.tertiary, () => context.go('/plan'))),
        Expanded(child: _buildActionBtn(context, context.tr('more_tools'), LucideIcons.layoutGrid, primaryColor, () => _showMoreToolsSheet(context))),
      ],
    );
  }

  void _showMoreToolsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('more_tools'),
              style: AppTypography.headlineSmall(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              children: [
                _buildActionBtn(context, context.tr('debts'), LucideIcons.coins, AppColors.warning, () {
                  Navigator.pop(ctx);
                  context.push('/debts');
                }),
                _buildActionBtn(context, context.tr('forecast'), LucideIcons.trendingUp, primaryColor, () {
                  Navigator.pop(ctx);
                  context.push('/forecast');
                }),
                _buildActionBtn(context, context.tr('calendar'), LucideIcons.calendar, AppColors.info, () {
                  Navigator.pop(ctx);
                  context.push('/calendar');
                }),
                _buildActionBtn(context, context.tr('monthly_review'), LucideIcons.fileCheck, AppColors.success, () {
                  Navigator.pop(ctx);
                  context.push('/monthly-review');
                }),
                _buildActionBtn(context, context.tr('reports'), LucideIcons.pieChart, AppColors.secondary, () {
                  Navigator.pop(ctx);
                  context.push('/reports');
                }),
                _buildActionBtn(context, context.tr('salary_allocation'), LucideIcons.split, primaryColor, () {
                  Navigator.pop(ctx);
                  context.push('/virtual-splits');
                }),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Text(
            label,
            style: AppTypography.labelSmall(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String action, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.headlineSmall(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        TextButton.icon(
          onPressed: onTap ?? () => context.go('/transactions'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Text(
            action,
            style: AppTypography.labelMedium(color: primaryColor).copyWith(fontWeight: FontWeight.bold),
          ),
          label: Icon(LucideIcons.chevronRight, size: 16, color: primaryColor),
        ),
      ],
    );
  }

  Widget _buildMonthlySummary(BuildContext context, AsyncValue summaryAsync, String currency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryData = summaryAsync.valueOrNull;

    if (summaryData == null && summaryAsync.isLoading) {
      return const GlassCard(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (summaryData == null) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(context.tr('item_not_found')),
      );
    }

    final summary = summaryData;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.arrowDownLeft, color: AppColors.income, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('income'), style: AppTypography.labelSmall(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                          Text(
                            _hideAmounts ? '••••••' : MoneyFormatter.formatNumber(summary.totalIncome, currency: currency),
                            style: AppTypography.bodyMedium(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                .copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.arrowUpRight, color: AppColors.expense, size: 18),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('expenses'), style: AppTypography.labelSmall(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                            Text(
                              _hideAmounts ? '••••••' : MoneyFormatter.formatNumber(summary.totalExpenses, currency: currency),
                              style: AppTypography.bodyMedium(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                  .copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('net_cash_flow'),
                style: AppTypography.labelMedium(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              Text(
                _hideAmounts
                    ? '••••••'
                    : MoneyFormatter.formatSigned(
                        summary.netCashFlow,
                        currency: currency,
                        isPositive: summary.netCashFlow >= 0,
                      ),
                style: AppTypography.bodyMedium(
                  color: summary.netCashFlow >= 0 ? AppColors.income : AppColors.expense,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEventsSection(BuildContext context, String currency) {
    final recurringAsync = ref.watch(activeRecurringProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return recurringAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const SizedBox.shrink();
        }

        final upcoming = events.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, context.tr('upcoming_obligations'), context.tr('view_all'), onTap: () => context.push('/recurring')),
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < upcoming.length; i++) ...[
                    if (i > 0)
                      Divider(
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                        height: 1,
                      ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: upcoming[i].type == 'income'
                              ? AppColors.income.withValues(alpha: 0.12)
                              : AppColors.expense.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          upcoming[i].type == 'income' ? LucideIcons.arrowDownLeft : LucideIcons.calendarClock,
                          color: upcoming[i].type == 'income' ? AppColors.income : AppColors.expense,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        upcoming[i].description,
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${context.tr('due_on')} ${DateHelper.formatShortDate(upcoming[i].nextOccurrence)} • ${upcoming[i].frequency}',
                        style: AppTypography.bodySmall(
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ),
                      trailing: Text(
                        _hideAmounts
                            ? '••••'
                            : MoneyFormatter.formatSigned(
                                upcoming[i].amountMinor,
                                currency: upcoming[i].currency,
                                isPositive: upcoming[i].type == 'income',
                              ),
                        style: AppTypography.bodyMedium(
                          color: upcoming[i].type == 'income'
                              ? AppColors.income
                              : (upcoming[i].type == 'expense' ? AppColors.expense : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, String currency) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.ghost,
                      size: 44,
                      color: isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.tr('no_recent_activity'),
                      style: AppTypography.bodyMedium(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/add-income'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(130, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
                      ),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: Text(context.tr('add_income')),
                    )
                  ],
                ),
              ),
            ),
          );
        }

        final displayTxns = transactions.take(5).toList();

        return GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int index = 0; index < displayTxns.length; index++) ...[
                if (index > 0)
                  Divider(
                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                    height: 1,
                  ),
                Builder(
                  builder: (context) {
                    final txn = displayTxns[index];
                    final isIncome = txn.type == 'income';
                    final isTransfer = txn.type == 'transfer';
                    
                    Color iconColor;
                    IconData icon;
                    if (isIncome) {
                      iconColor = AppColors.income;
                      icon = LucideIcons.arrowDownLeft;
                    } else if (isTransfer) {
                      iconColor = AppColors.transfer;
                      icon = LucideIcons.arrowRightLeft;
                    } else {
                      iconColor = AppColors.expense;
                      icon = LucideIcons.shoppingBag;
                    }

                    final displayTitle = txn.description.isNotEmpty
                        ? txn.description
                        : (isIncome ? (txn.incomeOrigin ?? context.tr('income')) : (txn.payee ?? context.tr('expense')));

                    return ListTile(
                      onTap: () => context.push('/transaction-detail/${txn.id}'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      title: Text(
                        displayTitle,
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        DateHelper.formatShortDate(txn.date),
                        style: AppTypography.bodySmall(
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ),
                      trailing: Text(
                        _hideAmounts
                            ? '••••'
                            : MoneyFormatter.formatSigned(
                                txn.amountMinor,
                                currency: txn.currency,
                                isPositive: isIncome,
                              ),
                        style: AppTypography.moneySmall(
                          color: isIncome
                              ? AppColors.income
                              : (txn.type == 'expense' ? AppColors.expense : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text(context.tr('item_not_found')),
    );
  }
}
