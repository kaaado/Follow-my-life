import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _currentPage = 1;
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
          _currentPage = 1;
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final queryParams = TransactionsQueryParams(
      month: _selectedMonth,
      type: _selectedFilterKey,
      searchQuery: _searchQuery,
      page: _currentPage,
      pageSize: 15,
    );
    final transactionsAsync = ref.watch(pagedTransactionsProvider(queryParams));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final monthLabel = DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('transactions')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(165),
          child: Column(
            children: [
              // ─── Month Navigation ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.chevronLeft, size: 20),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                          _currentPage = 1;
                        });
                      },
                    ),
                    Text(
                      monthLabel,
                      style: AppTypography.headlineSmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.chevronRight, size: 20),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                          _currentPage = 1;
                        });
                      },
                    ),
                  ],
                ),
              ),
              // ─── Search Field ──────────────────────────────────
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
                                _currentPage = 1;
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
              // ─── Filter Chips ──────────────────────────────────
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
                          if (selected) {
                            setState(() {
                              _selectedFilterKey = filterKey;
                              _currentPage = 1;
                            });
                          }
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
              data: (pagedResult) {
                final transactions = pagedResult.items;

                if (transactions.isEmpty) {
                  return AppEmptyState(
                    icon: LucideIcons.listX,
                    title: context.tr('no_transactions'),
                    message: context.tr('no_transactions_desc'),
                  );
                }

                final hasPaginationFooter = pagedResult.totalPages > 1;
                final itemCount = transactions.length + (hasPaginationFooter ? 1 : 0);

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index == transactions.length) {
                      // ─── Pagination Footer ─────────────────────
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(LucideIcons.chevronLeft, size: 16),
                              label: Text(context.tr('previous_page')),
                              onPressed: pagedResult.hasPreviousPage
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              child: Text(
                                '${context.tr('page_indicator')} $_currentPage / ${pagedResult.totalPages}',
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              label: Text(context.tr('next_page')),
                              icon: const Icon(LucideIcons.chevronRight, size: 16),
                              onPressed: pagedResult.hasNextPage
                                  ? () => setState(() => _currentPage++)
                                  : null,
                            ),
                          ],
                        ),
                      );
                    }

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

                    // Format title and subtitle
                    String titleText;
                    if (txn.description.isNotEmpty) {
                      titleText = txn.description;
                    } else if (isTransfer) {
                      final from = txn.incomeOrigin ?? '';
                      final to = txn.payee ?? '';
                      titleText = (from.isNotEmpty && to.isNotEmpty)
                          ? '$from → $to'
                          : context.tr('transfer');
                    } else if (isIncome) {
                      titleText = txn.incomeOrigin ?? context.tr('income');
                    } else {
                      titleText = txn.payee ?? context.tr('expense');
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
                            ref.invalidate(pagedTransactionsProvider);
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
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  titleText,
                                  style: AppTypography.bodyLarge(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (txn.referenceType == 'split') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    context.tr('split'),
                                    style: AppTypography.labelSmall(
                                      color: Theme.of(context).colorScheme.primary,
                                    ).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    DateHelper.formatDate(txn.date),
                                    style: AppTypography.bodySmall(
                                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                    ),
                                  ),
                                  if (isTransfer && txn.incomeOrigin != null && txn.payee != null) ...[
                                    Text(
                                      ' • ${txn.incomeOrigin} → ${txn.payee}',
                                      style: AppTypography.bodySmall(
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: Text(
                            isTransfer
                                ? MoneyFormatter.format(txn.amountMinor, currency: txn.currency)
                                : MoneyFormatter.formatSigned(
                                    txn.amountMinor,
                                    currency: txn.currency,
                                    isPositive: isIncome,
                                  ),
                            style: AppTypography.moneyMedium(
                              color: isIncome
                                  ? AppColors.income
                                  : (isTransfer
                                      ? AppColors.transfer
                                      : AppColors.expense),
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
