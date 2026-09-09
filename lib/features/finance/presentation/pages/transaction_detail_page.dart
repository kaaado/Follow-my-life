import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/utils/date_helper.dart';
import 'package:follow_my_life/core/widgets/glass_card.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:lucide_icons/lucide_icons.dart';

final transactionDetailProvider = FutureProvider.family<Transaction?, String>((ref, id) async {
  final result = await ref.watch(transactionRepositoryProvider).getTransactionById(id);
  return result.when(success: (data) => data, failure: (_) => null);
});

class TransactionDetailPage extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailPage({
    super.key,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnAsync = ref.watch(transactionDetailProvider(transactionId));
    final sourcesAsync = ref.watch(activeSourcesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('transaction_details')),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: AppColors.error),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: txnAsync.when(
        data: (txn) {
          if (txn == null) {
            return Center(child: Text(context.tr('item_not_found')));
          }

          final isIncome = txn.type == 'income';
          final isTransfer = txn.type == 'transfer';
          final sources = sourcesAsync.valueOrNull ?? [];
          final categories = categoriesAsync.valueOrNull ?? [];

          final source = sources.firstWhere(
            (s) => s.id == txn.sourceId,
            orElse: () => MoneySource(
              id: txn.sourceId,
              name: context.tr('other'),
              type: SourceType.cash,
              currency: txn.currency,
              icon: 'wallet',
              colorIndex: 0,
              initialBalanceMinor: 0,
              cachedBalanceMinor: 0,
              isActive: true,
              sortOrder: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          final category = categories.firstWhere(
            (c) => c.id == txn.categoryId,
            orElse: () => Category(
              id: 'cat_general',
              name: context.tr('category'),
              icon: 'tag',
              colorIndex: 0,
              isDefault: true,
              isActive: true,
              sortOrder: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          Color headerColor;
          IconData headerIcon;
          if (isIncome) {
            headerColor = AppColors.income;
            headerIcon = LucideIcons.arrowDownLeft;
          } else if (isTransfer) {
            headerColor = AppColors.transfer;
            headerIcon = LucideIcons.arrowRightLeft;
          } else {
            headerColor = AppColors.expense;
            headerIcon = LucideIcons.arrowUpRight;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),

                // Amount & Header Visual Card
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: headerColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(headerIcon, color: headerColor, size: 36),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        context.tr(txn.type).toUpperCase(),
                        style: AppTypography.labelMedium(color: headerColor),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        MoneyFormatter.formatSigned(
                          txn.amountMinor,
                          currency: txn.currency,
                          isPositive: isIncome,
                        ),
                        style: AppTypography.moneyLarge(
                          color: isIncome
                              ? AppColors.income
                              : (txn.type == 'expense' ? AppColors.expense : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        DateHelper.formatDate(txn.date),
                        style: AppTypography.bodySmall(
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Information Card
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        context,
                        label: context.tr('money_account'),
                        value: source.name,
                        icon: LucideIcons.wallet,
                      ),
                      const Divider(height: AppSpacing.xl),
                      if (isIncome && txn.incomeOrigin != null && txn.incomeOrigin!.isNotEmpty) ...[
                        _buildDetailRow(
                          context,
                          label: context.tr('income_origin'),
                          value: txn.incomeOrigin!,
                          icon: LucideIcons.building,
                        ),
                        const Divider(height: AppSpacing.xl),
                      ],
                      if (!isIncome && txn.payee != null && txn.payee!.isNotEmpty) ...[
                        _buildDetailRow(
                          context,
                          label: context.tr('payee_merchant'),
                          value: txn.payee!,
                          icon: LucideIcons.store,
                        ),
                        const Divider(height: AppSpacing.xl),
                      ],
                      if (txn.categoryId != null) ...[
                        _buildDetailRow(
                          context,
                          label: context.tr('category'),
                          value: context.tr(category.name),
                          icon: LucideIcons.tag,
                        ),
                        const Divider(height: AppSpacing.xl),
                      ],
                      _buildDetailRow(
                        context,
                        label: context.tr('description'),
                        value: txn.description.isEmpty ? context.tr('no_description') : txn.description,
                        icon: LucideIcons.fileText,
                      ),
                      if (txn.note != null && txn.note!.isNotEmpty) ...[
                        const Divider(height: AppSpacing.xl),
                        _buildDetailRow(
                          context,
                          label: context.tr('note'),
                          value: txn.note!,
                          icon: LucideIcons.stickyNote,
                        ),
                      ],
                      if (txn.referenceType != null) ...[
                        const Divider(height: AppSpacing.xl),
                        _buildDetailRow(
                          context,
                          label: context.tr('source_reference'),
                          value: '${txn.referenceType?.toUpperCase()} (${txn.referenceId})',
                          icon: LucideIcons.link,
                        ),
                      ],
                    ],
                  ),
                ),

                // Itemized Split Transactions (if any)
                _buildSplitsSection(context, ref, txn.id),

                if (!isIncome) ...[
                  ElevatedButton.icon(
                    onPressed: () => _showRefundDialog(context, ref, txn),
                    icon: const Icon(LucideIcons.undo, color: Colors.white),
                    label: Text(context.tr('record_linked_refund')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.income,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Delete Action Button
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(LucideIcons.trash2, color: AppColors.error),
                  label: Text(context.tr('delete_transaction'), style: const TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(context.tr('item_not_found'))),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.labelSmall(
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text(context.tr('delete_transaction')),
            content: Text(context.tr('delete_transaction_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(context.tr('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(context.tr('delete')),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final result = await ref.read(transactionRepositoryProvider).deleteTransaction(transactionId);
    if (context.mounted) {
      if (result.isSuccess) {
        AppFeedback.showSuccess(context, context.tr('item_deleted'));
        context.pop();
      } else {
        AppFeedback.showError(context, result.failure.message);
      }
    }
  }

  void _showRefundDialog(BuildContext context, WidgetRef ref, Transaction originalTxn) {
    final refundController = TextEditingController(
      text: (originalTxn.amountMinor / 100).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(context.tr('record_refund')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.tr('original_expense')}: ${originalTxn.description}'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: refundController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.tr('refund_amount'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(refundController.text.trim());
              if (val == null || val <= 0) {
                AppFeedback.showError(context, context.tr('amount_positive'));
                return;
              }

              final minor = (val * 100).round();
              final result = await ref.read(transactionRepositoryProvider).recordRefund(
                    originalExpenseId: originalTxn.id,
                    refundAmountMinor: minor,
                    date: DateTime.now(),
                  );

              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
                if (result.isSuccess) {
                  AppFeedback.showSuccess(context, context.tr('saved_successfully'));
                } else {
                  AppFeedback.showError(context, result.failure.message);
                }
              }
            },
            child: Text(context.tr('submit_refund')),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitsSection(BuildContext context, WidgetRef ref, String txnId) {
    final splitsAsync = ref.watch(splitsForTransactionProvider(txnId));

    return splitsAsync.when(
      data: (splits) {
        if (splits.isEmpty) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.tr('itemized_splits'),
              style: AppTypography.headlineSmall(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                children: splits.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.note ?? context.tr('split'),
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          MoneyFormatter.format(item.amountMinor),
                          style: AppTypography.labelLarge(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
