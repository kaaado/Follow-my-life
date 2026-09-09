import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/utils/date_helper.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/core/widgets/app_empty_state.dart';
import 'package:follow_my_life/core/widgets/glass_card.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(activeRecurringProvider);
    final sourcesAsync = ref.watch(activeSourcesProvider);
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('recurring')),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => context.push('/add-recurring'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-recurring'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: recurringAsync.when(
        data: (recurrings) {
          if (recurrings.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.repeat,
              title: context.tr('no_recurring_items'),
              message: context.tr('recurring_desc'),
              actionLabel: context.tr('add_recurring'),
              onAction: () => context.push('/add-recurring'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: recurrings.length,
            itemBuilder: (context, index) {
              final item = recurrings[index];
              final isIncome = item.type == 'income';
              final freqKey = 'freq_${item.frequency.toLowerCase()}';

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (isIncome ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isIncome ? LucideIcons.arrowDownLeft : LucideIcons.repeat,
                          color: isIncome ? AppColors.income : AppColors.expense,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.description,
                              style: AppTypography.bodyLarge(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ).copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${context.tr(freqKey)} • ${context.tr('next')}: ${DateHelper.formatDate(item.nextOccurrence)}',
                              style: AppTypography.bodySmall(
                                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            MoneyFormatter.formatSigned(
                              item.amountMinor,
                              currency: item.currency,
                              isPositive: isIncome,
                            ),
                            style: AppTypography.moneyMedium(
                              color: isIncome ? AppColors.income : AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          LucideIcons.moreVertical,
                          size: 18,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showEditRecurringDialog(
                              context,
                              ref,
                              item,
                              sourcesAsync.valueOrNull ?? [],
                              categoriesAsync.valueOrNull ?? [],
                            );
                          } else if (val == 'delete') {
                            _confirmDeleteRecurring(context, ref, item);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(LucideIcons.edit2, size: 16),
                                const SizedBox(width: 8),
                                Text(context.tr('edit')),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Text(context.tr('delete'), style: const TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(context.tr('error_loading_recurring'))),
      ),
    );
  }

  void _showEditRecurringDialog(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction item,
    List<MoneySource> sources,
    List<Category> categories,
  ) {
    final descCtrl = TextEditingController(text: item.description);
    final amountCtrl = TextEditingController(
      text: MoneyFormatter.formatNumber(item.amountMinor, currency: item.currency),
    );
    String frequency = item.frequency;
    String sourceId = sources.any((s) => s.id == item.sourceId)
        ? item.sourceId
        : (sources.isNotEmpty ? sources.first.id : item.sourceId);
    String? categoryId = item.categoryId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(context.tr('edit_recurring')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: context.tr('description')),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: context.tr('amount')),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: ['daily', 'weekly', 'monthly', 'yearly'].contains(frequency)
                      ? frequency
                      : 'monthly',
                  items: ['daily', 'weekly', 'monthly', 'yearly']
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(context.tr('freq_$f')),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => frequency = val);
                  },
                  decoration: InputDecoration(labelText: context.tr('frequency')),
                ),
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: sourceId,
                    items: sources
                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => sourceId = val);
                    },
                    decoration: InputDecoration(labelText: context.tr('source')),
                  ),
                ],
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String?>(
                    initialValue: categories.any((c) => c.id == categoryId) ? categoryId : null,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(context.tr('not_set')),
                      ),
                      ...categories.map((c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.name),
                          )),
                    ],
                    onChanged: (val) {
                      setDialogState(() => categoryId = val);
                    },
                    decoration: InputDecoration(labelText: context.tr('category')),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = MoneyFormatter.parseToMinor(amountCtrl.text.trim());
                if (descCtrl.text.trim().isNotEmpty && amount != null) {
                  final result = await ref.read(recurringRepositoryProvider).updateRecurring(
                        id: item.id,
                        description: descCtrl.text.trim(),
                        amountMinor: amount,
                        frequency: frequency,
                        sourceId: sourceId,
                        categoryId: categoryId,
                      );
                  ref.invalidate(activeRecurringProvider);
                  ref.invalidate(financialSummaryProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    if (result.isSuccess) {
                      AppFeedback.showSuccess(context, context.tr('saved'));
                    } else {
                      AppFeedback.showError(context, result.failure.message);
                    }
                  }
                }
              },
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRecurring(BuildContext context, WidgetRef ref, RecurringTransaction item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_recurring')),
        content: Text(context.tr('delete_item_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              final result = await ref.read(recurringRepositoryProvider).deleteRecurring(item.id);
              ref.invalidate(activeRecurringProvider);
              ref.invalidate(financialSummaryProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                if (result.isSuccess) {
                  AppFeedback.showSuccess(context, context.tr('item_deleted'));
                } else {
                  AppFeedback.showError(context, result.failure.message);
                }
              }
            },
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
  }
}
