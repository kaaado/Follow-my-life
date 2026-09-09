import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/utils/date_helper.dart';
import 'package:follow_my_life/core/widgets/app_empty_state.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/core/widgets/app_skeleton.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String _selectedFilterKey = 'all';
  String _searchQuery = '';
  bool _isSearching = false;
  Timer? _debounceTimer;
  final List<String> _filterKeys = ['all', 'income', 'expense', 'transfer'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _isSearching = true;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = val.trim().toLowerCase();
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('transactions')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(115),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: context.tr('search'),
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty || _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () {
                              _debounceTimer?.cancel();
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _isSearching = false;
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterKeys.length,
                  itemBuilder: (context, index) {
                    final filterKey = _filterKeys[index];
                    final isSelected = _selectedFilterKey == filterKey;
                    final label = filterKey == 'all' ? context.tr('all') : context.tr(filterKey);
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedFilterKey = filterKey);
                        },
                        labelStyle: AppTypography.labelMedium(
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isSearching
          ? ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: 6,
              separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, index) => const SkeletonCard(),
            )
          : transactionsAsync.when(
              data: (allTransactions) {
          final transactions = allTransactions.where((t) {
            final matchesFilter = _selectedFilterKey == 'all' || t.type.toLowerCase() == _selectedFilterKey;
            final matchesSearch = _searchQuery.isEmpty ||
                t.description.toLowerCase().contains(_searchQuery) ||
                (t.note != null && t.note!.toLowerCase().contains(_searchQuery));
            return matchesFilter && matchesSearch;
          }).toList();

          if (transactions.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.listX,
              title: context.tr('no_transactions'),
              message: context.tr('no_transactions_desc'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final txn = transactions[index];
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

              return Dismissible(
                key: Key(txn.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: const Icon(LucideIcons.trash2, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(context.tr('delete_transaction')),
                          content: Text(context.tr('delete_transaction_confirm')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(context.tr('cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
                              child: Text(context.tr('delete')),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (direction) async {
                  final result = await ref.read(transactionRepositoryProvider).deleteTransaction(txn.id);
                  if (context.mounted) {
                    if (result.isSuccess) {
                      AppFeedback.showSuccess(context, context.tr('item_deleted'));
                    } else {
                      AppFeedback.showError(context, result.failure.message);
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: ListTile(
                    onTap: () => context.push('/transaction/${txn.id}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    title: Text(
                      txn.description.isEmpty ? (isIncome ? context.tr('income') : context.tr('expense')) : txn.description,
                      style: AppTypography.bodyLarge(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          DateHelper.formatDate(txn.date),
                          style: AppTypography.bodySmall(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                        ),
                      ],
                    ),
                    trailing: Text(
                      MoneyFormatter.formatSigned(
                        txn.amountMinor,
                        currency: txn.currency,
                        isPositive: isIncome,
                      ),
                      style: AppTypography.moneyMedium(
                        color: isIncome
                            ? AppColors.income
                            : (txn.type == 'expense' ? AppColors.expense : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          itemCount: 6,
          separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, index) => const SkeletonCard(),
        ),
        error: (err, stack) => AppEmptyState(
          icon: LucideIcons.alertTriangle,
          title: context.tr('item_not_found'),
          message: context.tr('no_transactions_desc'),
        ),
      ),
    );
  }
}
