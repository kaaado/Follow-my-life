import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/utils/date_helper.dart';
import 'package:follow_my_life/core/utils/currency_conversion_service.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:follow_my_life/features/finance/data/repositories/split_transaction_repository.dart';
import 'package:lucide_icons/lucide_icons.dart';

class _SplitAllocationItem {
  String? sourceId;
  final TextEditingController amountController;
  String? categoryId;

  _SplitAllocationItem({
    this.sourceId,
    required String initialAmount,
    this.categoryId,
  }) : amountController = TextEditingController(text: initialAmount);

  void dispose() {
    amountController.dispose();
  }
}

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key});

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedSourceId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Split transaction support
  bool _isSplitAcrossSources = false;
  final List<_SplitAllocationItem> _splitItems = [];

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    for (final item in _splitItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addSplitItem(List<MoneySource> sources) {
    setState(() {
      final defaultSource = sources.isNotEmpty ? sources.first.id : null;
      final newItem = _SplitAllocationItem(
        sourceId: defaultSource,
        initialAmount: '',
        categoryId: _selectedCategoryId,
      );
      newItem.amountController.addListener(() => setState(() {}));
      _splitItems.add(newItem);
    });
  }

  void _removeSplitItem(int index) {
    if (_splitItems.length <= 1) return;
    setState(() {
      final removed = _splitItems.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _saveExpense(List<MoneySource> sources) async {
    if (!_formKey.currentState!.validate()) return;

    final totalAmount = MoneyFormatter.parseToMinor(_amountController.text) ?? 0;
    if (totalAmount <= 0) {
      AppFeedback.showError(context, context.tr('amount_positive'));
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);
    final desc = _descController.text.trim().isEmpty ? context.tr('expense') : _descController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (_isSplitAcrossSources) {
        if (_splitItems.isEmpty) {
          AppFeedback.showError(context, context.tr('add_split_source'));
          return;
        }

        final sourceMap = {for (final s in sources) s.id: s};
        final List<SplitItemInput> splitInputs = [];

        for (final item in _splitItems) {
          if (item.sourceId == null) {
            AppFeedback.showError(context, context.tr('select_source'));
            return;
          }
          final splitSrc = sourceMap[item.sourceId];
          if (splitSrc == null) {
            AppFeedback.showError(context, context.tr('select_source'));
            return;
          }
          final itemAmount = MoneyFormatter.parseToMinor(item.amountController.text) ?? 0;
          if (itemAmount <= 0) {
            AppFeedback.showError(context, context.tr('amount_positive'));
            return;
          }

          final rate = CurrencyConversionService.getExchangeRate(splitSrc.currency, 'DZD');
          final normalized = CurrencyConversionService.convert(
            amountMinor: itemAmount,
            fromCurrency: splitSrc.currency,
            toCurrency: 'DZD',
          );

          splitInputs.add(SplitItemInput(
            sourceId: item.sourceId,
            categoryId: item.categoryId ?? _selectedCategoryId,
            amountMinor: itemAmount,
            currency: splitSrc.currency,
            exchangeRate: rate,
            normalizedAmountMinor: normalized,
          ));
        }

        final validation = CurrencyConversionService.validateSplits(
          totalAmountMinor: totalAmount,
          baseCurrency: 'DZD',
          splits: splitInputs,
        );

        if (!validation.isValid) {
          AppFeedback.showError(
            context,
            validation.errorMessage ?? context.tr('split_sum_mismatch'),
          );
          return;
        }

        final result = await repo.recordSplitExpense(
          amountMinor: totalAmount,
          description: desc,
          date: _selectedDate,
          currency: 'DZD',
          categoryId: _selectedCategoryId,
          splits: splitInputs,
        );

        result.when(
          success: (_) {
            if (mounted) {
              AppFeedback.showSuccess(context, context.tr('saved_successfully'));
              context.pop();
            }
          },
          failure: (error) {
            if (mounted) {
              AppFeedback.showError(context, error.message);
            }
          },
        );
      } else {
        if (_selectedSourceId == null) {
          AppFeedback.showError(context, context.tr('need_source_first'));
          return;
        }

        final result = await repo.recordExpense(
          amountMinor: totalAmount,
          sourceId: _selectedSourceId!,
          categoryId: _selectedCategoryId,
          description: desc,
          date: _selectedDate,
        );

        result.when(
          success: (_) {
            if (mounted) {
              AppFeedback.showSuccess(context, context.tr('saved_successfully'));
              context.pop();
            }
          },
          failure: (error) {
            if (mounted) {
              AppFeedback.showError(context, error.message);
            }
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(activeSourcesProvider);
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('add_expense')),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    final sources = sourcesAsync.valueOrNull ?? [];
                    if (sources.isNotEmpty) _saveExpense(sources);
                  },
            child: Text(
              context.tr('save'),
              style: AppTypography.labelLarge(color: AppColors.expense),
            ),
          ),
        ],
      ),
      body: sourcesAsync.when(
        data: (sources) {
          if (sources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.wallet, size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: AppSpacing.md),
                  Text(context.tr('need_source_first')),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => context.pushReplacement('/add-source'),
                    child: Text(context.tr('add_source')),
                  ),
                ],
              ),
            );
          }

          _selectedSourceId ??= sources.first.id;

          // Initialize splits if empty and toggle enabled
          if (_isSplitAcrossSources && _splitItems.isEmpty) {
            _addSplitItem(sources);
            _addSplitItem(sources);
          }

          final sourceMap = {for (final s in sources) s.id: s};
          final totalExpenseMinor = MoneyFormatter.parseToMinor(_amountController.text) ?? 0;

          // Calculate normalized allocated sum
          int totalAllocatedNormalized = 0;
          if (_isSplitAcrossSources) {
            for (final item in _splitItems) {
              final minor = MoneyFormatter.parseToMinor(item.amountController.text) ?? 0;
              final src = item.sourceId != null ? sourceMap[item.sourceId] : null;
              final cur = src?.currency ?? 'DZD';
              final norm = CurrencyConversionService.convert(
                amountMinor: minor,
                fromCurrency: cur,
                toCurrency: 'DZD',
              );
              totalAllocatedNormalized += norm;
            }
          }
          final remainingNormalized = totalExpenseMinor - totalAllocatedNormalized;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount
                  Center(
                    child: SizedBox(
                      width: 220,
                      child: TextFormField(
                        controller: _amountController,
                        style: AppTypography.moneyLarge(color: AppColors.expense),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: AppTypography.moneyLarge(
                            color: isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val == null || val.isEmpty) return context.tr('amount_required');
                          final parsed = MoneyFormatter.parseToMinor(val);
                          if (parsed == null || parsed <= 0) return context.tr('amount_positive');
                          return null;
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Description
                  TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: context.tr('what_was_this_for'),
                      hintText: context.tr('payee_hint'),
                      prefixIcon: const Icon(LucideIcons.alignLeft),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Category
                  categoriesAsync.when(
                    data: (categories) {
                      if (categories.isEmpty) return const SizedBox.shrink();
                      _selectedCategoryId ??= categories.first.id;

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: context.tr('category'),
                          prefixIcon: const Icon(LucideIcons.tags),
                        ),
                        items: categories.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategoryId = val);
                        },
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Center(child: Text(context.tr('item_not_found'))),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Date picker
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) setState(() => _selectedDate = date);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.tr('date'),
                        prefixIcon: const Icon(LucideIcons.calendar),
                      ),
                      child: Text(DateHelper.formatDate(_selectedDate)),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ─── Split Across Sources Toggle ───────────────
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: SwitchListTile(
                      value: _isSplitAcrossSources,
                      onChanged: (val) {
                        setState(() {
                          _isSplitAcrossSources = val;
                          if (val && _splitItems.isEmpty) {
                            _addSplitItem(sources);
                            _addSplitItem(sources);
                          }
                        });
                      },
                      title: Text(
                        context.tr('split_payment'),
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      secondary: Icon(
                        LucideIcons.split,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ─── Single Source vs Multi-Source Section ──────
                  if (!_isSplitAcrossSources) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSourceId,
                      decoration: InputDecoration(
                        labelText: context.tr('paid_from'),
                        prefixIcon: const Icon(LucideIcons.arrowUpFromLine, color: AppColors.expense),
                      ),
                      items: sources.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.name} (${s.currency})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSourceId = val);
                      },
                    ),
                  ] else ...[
                    // Multi-Source Split Allocation Cards
                    Text(
                      context.tr('split_payment'),
                      style: AppTypography.headlineSmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    ..._splitItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final split = entry.value;
                      final splitSrc = split.sourceId != null ? sourceMap[split.sourceId] : null;
                      final splitCurrency = splitSrc?.currency ?? 'DZD';
                      final itemMinor = MoneyFormatter.parseToMinor(split.amountController.text) ?? 0;
                      final normAmount = CurrencyConversionService.convert(
                        amountMinor: itemMinor,
                        fromCurrency: splitCurrency,
                        toCurrency: 'DZD',
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${context.tr('funding_source')} #${idx + 1}',
                                  style: AppTypography.labelMedium(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                if (_splitItems.length > 1)
                                  IconButton(
                                    icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.error),
                                    onPressed: () => _removeSplitItem(idx),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButtonFormField<String>(
                              initialValue: split.sourceId,
                              decoration: InputDecoration(
                                labelText: context.tr('funding_source'),
                                prefixIcon: const Icon(LucideIcons.wallet, size: 20),
                              ),
                              items: sources.map((s) {
                                return DropdownMenuItem(
                                  value: s.id,
                                  child: Text('${s.name} (${s.currency})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => split.sourceId = val);
                                }
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: split.amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: '${context.tr('split_amount')} ($splitCurrency)',
                                prefixIcon: const Icon(LucideIcons.coins, size: 20),
                              ),
                            ),
                            if (splitCurrency != 'DZD' && itemMinor > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${context.tr('converted_amount')}: ≈ ${MoneyFormatter.format(normAmount, currency: 'DZD')}',
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    OutlinedButton.icon(
                      onPressed: () => _addSplitItem(sources),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: Text(context.tr('add_split_source')),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Live Split Balance Validation Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: remainingNormalized == 0
                            ? AppColors.income.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(
                          color: remainingNormalized == 0 ? AppColors.income : AppColors.error,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('allocated'),
                                style: AppTypography.bodyMedium(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                MoneyFormatter.format(totalAllocatedNormalized, currency: 'DZD'),
                                style: AppTypography.bodyMedium(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('remaining_to_allocate'),
                                style: AppTypography.bodyMedium(
                                  color: remainingNormalized == 0 ? AppColors.income : AppColors.error,
                                ),
                              ),
                              Text(
                                MoneyFormatter.format(remainingNormalized, currency: 'DZD'),
                                style: AppTypography.bodyMedium(
                                  color: remainingNormalized == 0 ? AppColors.income : AppColors.error,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (remainingNormalized != 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              context.tr('split_sum_mismatch'),
                              style: AppTypography.bodySmall(color: AppColors.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(context.tr('item_not_found'))),
      ),
    );
  }
}
