import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/widgets/glass_card.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';

class DebtPage extends ConsumerStatefulWidget {
  const DebtPage({super.key});

  @override
  ConsumerState<DebtPage> createState() => _DebtPageState();
}

class _DebtPageState extends ConsumerState<DebtPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtsAsync = ref.watch(activeDebtsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('debts')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(text: context.tr('i_owe')),
            Tab(text: context.tr('owed_to_me')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-debt'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        tooltip: context.tr('add_debt'),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: debtsAsync.when(
        data: (debts) {
          final iOweList = debts.where((d) => d.type == 'i_owe').toList();
          final owedToMeList = debts.where((d) => d.type == 'owed_to_me').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildDebtList(context, iOweList, isIOwe: true, isDark: isDark),
              _buildDebtList(context, owedToMeList, isIOwe: false, isDark: isDark),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertTriangle, size: 48, color: AppColors.error),
                const SizedBox(height: AppSpacing.sm),
                Text(context.tr('error_loading_debts'), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => ref.invalidate(activeDebtsProvider),
                  child: Text(context.tr('retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebtList(
    BuildContext context,
    List<Debt> items, {
    required bool isIOwe,
    required bool isDark,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isIOwe ? LucideIcons.checkCircle : LucideIcons.wallet,
                size: 64,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isIOwe ? context.tr('no_active_debts') : context.tr('no_pending_receivables'),
                style: AppTypography.headlineMedium(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isIOwe ? context.tr('no_debts_desc') : context.tr('no_receivables_desc'),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalAmount = items.fold<int>(0, (sum, item) => sum + item.amountMinor);
    final totalPaid = items.fold<int>(0, (sum, item) => sum + item.paidAmountMinor);
    final totalRemaining = totalAmount - totalPaid;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Summary Header Card
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIOwe ? context.tr('total_debt_balance') : context.tr('total_receivables'),
                      style: AppTypography.labelMedium(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      MoneyFormatter.format(totalRemaining),
                      style: AppTypography.headlineLarge(
                        color: isIOwe ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isIOwe ? AppColors.expense : AppColors.income).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIOwe ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
                    color: isIOwe ? AppColors.expense : AppColors.income,
                  ),
                ),
              ],
            ),
          ),
        ),

        // List of items
        ...items.map((debt) {
          final progress = (debt.amountMinor > 0)
              ? (debt.paidAmountMinor / debt.amountMinor).clamp(0.0, 1.0)
              : 0.0;
          final remaining = debt.amountMinor - debt.paidAmountMinor;

          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          debt.personName,
                          style: AppTypography.headlineSmall(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: debt.status == 'paid'
                              ? AppColors.income.withValues(alpha: 0.2)
                              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          debt.status.toUpperCase().replaceAll('_', ' '),
                          style: AppTypography.labelSmall(
                            color: debt.status == 'paid' ? AppColors.income : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${context.tr('original_label')}: ${MoneyFormatter.format(debt.amountMinor, currency: debt.currency)}  •  ${context.tr('remaining_label')}: ${MoneyFormatter.format(remaining, currency: debt.currency)}',
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Linear Progress Indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isIOwe ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (debt.dueDate != null)
                        Text(
                          '${context.tr('due_on')} ${debt.dueDate!.day}/${debt.dueDate!.month}/${debt.dueDate!.year}',
                          style: AppTypography.labelSmall(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton.icon(
                        onPressed: () => _showPaymentDialog(context, debt),
                        icon: Icon(isIOwe ? LucideIcons.creditCard : LucideIcons.download),
                        label: Text(isIOwe ? context.tr('pay_back') : context.tr('collect')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isIOwe ? AppColors.expense : AppColors.income,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showPaymentDialog(BuildContext context, Debt debt) {
    final amountController = TextEditingController(
      text: ((debt.amountMinor - debt.paidAmountMinor) / 100).toStringAsFixed(2),
    );
    String? selectedSourceId;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Consumer(
          builder: (context, ref, child) {
            final sourcesAsync = ref.watch(activeSourcesProvider);

            return AlertDialog(
              title: Text(debt.type == 'i_owe' ? context.tr('record_payment') : context.tr('record_collection')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${context.tr('party_label')}: ${debt.personName}'),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: context.tr('amount'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    sourcesAsync.when(
                      data: (sources) {
                        if (sources.isEmpty) {
                          return Text(context.tr('no_sources'));
                        }
                        selectedSourceId ??= sources.first.id;
                        return DropdownButtonFormField<String>(
                          initialValue: selectedSourceId,
                          items: sources
                              .map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.name),
                                  ))
                              .toList(),
                          onChanged: (val) => selectedSourceId = val,
                          decoration: InputDecoration(
                            labelText: context.tr('source'),
                            border: const OutlineInputBorder(),
                          ),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (err, _) => Text(context.tr('error_loading_sources')),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(context.tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amtVal = double.tryParse(amountController.text);
                    if (amtVal == null || amtVal <= 0 || selectedSourceId == null) {
                      AppFeedback.showError(context, context.tr('invalid_amount_source'));
                      return;
                    }

                    final minorVal = (amtVal * 100).round();
                    final result = await ref.read(debtRepositoryProvider).recordPayment(
                          debtId: debt.id,
                          sourceId: selectedSourceId!,
                          amountMinor: minorVal,
                          date: DateTime.now(),
                        );

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      if (result.isSuccess) {
                        AppFeedback.showSuccess(context, context.tr('debt_payment_recorded'));
                      } else {
                        AppFeedback.showError(context, result.failure.message);
                      }
                    }
                  },
                  child: Text(context.tr('submit')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
