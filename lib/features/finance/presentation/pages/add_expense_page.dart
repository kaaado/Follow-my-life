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

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key});

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  final Set<String> _selectedSourceIds = {};
  final Map<String, TextEditingController> _splitControllers = {};
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    for (final ctrl in _splitControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _splitEvenly(int totalExpenseMinor, List<MoneySource> sources) {
    if (_selectedSourceIds.isEmpty || totalExpenseMinor <= 0) return;
    final count = _selectedSourceIds.length;
    final eachMinor = totalExpenseMinor ~/ count;
    final remainder = totalExpenseMinor % count;

    int i = 0;
    for (final sId in _selectedSourceIds) {
      final amt = eachMinor + (i == 0 ? remainder : 0);
      final ctrl = _splitControllers.putIfAbsent(
        sId,
        () => TextEditingController()..addListener(() => setState(() {})),
      );
      ctrl.text = (amt / 100.0).toStringAsFixed(2);
      i++;
    }
    setState(() {});
  }

  Future<void> _saveExpense(List<MoneySource> sources) async {
    if (!_formKey.currentState!.validate()) return;

    final totalAmount = MoneyFormatter.parseToMinor(_amountController.text) ?? 0;
    if (totalAmount <= 0) {
      AppFeedback.showError(context, context.tr('amount_positive'));
      return;
    }

    if (_selectedSourceIds.isEmpty) {
      AppFeedback.showError(context, context.tr('select_at_least_one_source'));
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);
    final desc = _descController.text.trim().isEmpty ? context.tr('expense') : _descController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (_selectedSourceIds.length > 1) {
        // Multi-Source Split Expense
        final sourceMap = {for (final s in sources) s.id: s};
        final List<SplitItemInput> splitInputs = [];

        for (final sId in _selectedSourceIds) {
          final splitSrc = sourceMap[sId];
          if (splitSrc == null) {
            AppFeedback.showError(context, context.tr('select_source'));
            return;
          }
          final ctrl = _splitControllers[sId];
          final itemAmount = MoneyFormatter.parseToMinor(ctrl?.text ?? '') ?? 0;
          if (itemAmount <= 0) {
            AppFeedback.showError(context, 'Please specify an allocated amount for ${splitSrc.name}.');
            return;
          }

          final rate = CurrencyConversionService.getExchangeRate(splitSrc.currency, 'DZD');
          final normalized = CurrencyConversionService.convert(
            amountMinor: itemAmount,
            fromCurrency: splitSrc.currency,
            toCurrency: 'DZD',
          );

          splitInputs.add(SplitItemInput(
            sourceId: sId,
            categoryId: _selectedCategoryId,
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
        // Single Source Expense
        final singleSourceId = _selectedSourceIds.first;
        final result = await repo.recordExpense(
          amountMinor: totalAmount,
          sourceId: singleSourceId,
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

          if (_selectedSourceIds.isEmpty && sources.isNotEmpty) {
            _selectedSourceIds.add(sources.first.id);
          }

          final sourceMap = {for (final s in sources) s.id: s};
          final totalExpenseMinor = MoneyFormatter.parseToMinor(_amountController.text) ?? 0;

          // Calculate normalized allocated sum across selected sources
          int totalAllocatedNormalized = 0;
          if (_selectedSourceIds.length > 1) {
            for (final sId in _selectedSourceIds) {
              final ctrl = _splitControllers[sId];
              final minor = MoneyFormatter.parseToMinor(ctrl?.text ?? '') ?? 0;
              final src = sourceMap[sId];
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
                        onChanged: (_) {
                          if (_selectedSourceIds.length > 1 && totalAllocatedNormalized == 0) {
                            _splitEvenly(MoneyFormatter.parseToMinor(_amountController.text) ?? 0, sources);
                          }
                          setState(() {});
                        },
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

                  const SizedBox(height: AppSpacing.xl),

                  // ─── Choose Source(s) of Money (Multi-Check) ───────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.wallet, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            context.tr('choose_funding_sources'),
                            style: AppTypography.headlineSmall(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      // All Sources Toggle Button
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Theme.of(context).colorScheme.primary,
                        ),
                        icon: Icon(
                          _selectedSourceIds.length == sources.length
                              ? LucideIcons.checkCheck
                              : LucideIcons.layers,
                          size: 16,
                        ),
                        label: Text(context.tr('all_sources')),
                        onPressed: () {
                          setState(() {
                            if (_selectedSourceIds.length == sources.length) {
                              _selectedSourceIds.clear();
                              _selectedSourceIds.add(sources.first.id);
                            } else {
                              _selectedSourceIds.clear();
                              for (final s in sources) {
                                _selectedSourceIds.add(s.id);
                                _splitControllers.putIfAbsent(
                                  s.id,
                                  () => TextEditingController()..addListener(() => setState(() {})),
                                );
                              }
                              if (totalExpenseMinor > 0) {
                                _splitEvenly(totalExpenseMinor, sources);
                              }
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Multi-Check Source Selection Cards
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: sources.map((s) {
                      final isChecked = _selectedSourceIds.contains(s.id);
                      return InkWell(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        onTap: () {
                          setState(() {
                            if (isChecked) {
                              if (_selectedSourceIds.length > 1) {
                                _selectedSourceIds.remove(s.id);
                                _splitControllers[s.id]?.dispose();
                                _splitControllers.remove(s.id);
                              } else {
                                AppFeedback.showError(context, context.tr('select_at_least_one_source'));
                              }
                            } else {
                              _selectedSourceIds.add(s.id);
                              _splitControllers.putIfAbsent(
                                s.id,
                                () => TextEditingController()..addListener(() => setState(() {})),
                              );
                              if (totalExpenseMinor > 0) {
                                _splitEvenly(totalExpenseMinor, sources);
                              }
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: isChecked
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                                : (isDark ? AppColors.darkCard : AppColors.lightCard),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: isChecked
                                  ? Theme.of(context).colorScheme.primary
                                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              width: isChecked ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isChecked ? LucideIcons.checkSquare : LucideIcons.square,
                                size: 18,
                                color: isChecked
                                    ? Theme.of(context).colorScheme.primary
                                    : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                s.name,
                                style: AppTypography.bodyMedium(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: isChecked ? FontWeight.bold : FontWeight.normal),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '(${MoneyFormatter.format(s.cachedBalanceMinor, currency: s.currency)})',
                                style: AppTypography.bodySmall(
                                  color: isChecked
                                      ? Theme.of(context).colorScheme.primary
                                      : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ─── Multi-Source Split Allocation Cards ───────────
                  if (_selectedSourceIds.length > 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.split, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${context.tr('split_payment')} (${_selectedSourceIds.length} sources)',
                              style: AppTypography.headlineSmall(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          icon: const Icon(LucideIcons.divide, size: 14),
                          label: Text(context.tr('split_evenly')),
                          onPressed: () => _splitEvenly(totalExpenseMinor, sources),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    ..._selectedSourceIds.map((sId) {
                      final s = sourceMap[sId]!;
                      final ctrl = _splitControllers.putIfAbsent(
                        sId,
                        () => TextEditingController()..addListener(() => setState(() {})),
                      );
                      final itemMinor = MoneyFormatter.parseToMinor(ctrl.text) ?? 0;
                      final normAmount = CurrencyConversionService.convert(
                        amountMinor: itemMinor,
                        fromCurrency: s.currency,
                        toCurrency: 'DZD',
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                                  s.name,
                                  style: AppTypography.labelLarge(
                                    color: Theme.of(context).colorScheme.primary,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Available: ${MoneyFormatter.format(s.cachedBalanceMinor, currency: s.currency)}',
                                  style: AppTypography.bodySmall(
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              controller: ctrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: '${context.tr('split_amount')} (${s.currency})',
                                prefixIcon: const Icon(LucideIcons.coins, size: 20),
                              ),
                            ),
                            if (s.currency != 'DZD' && itemMinor > 0) ...[
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

                    const SizedBox(height: AppSpacing.sm),

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
                  ] else ...[
                    // Single Source Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkCard : AppColors.lightCard),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.checkCircle2, size: 18, color: AppColors.income),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Paid in full from ${sourceMap[_selectedSourceIds.first]?.name ?? "source"}. Select additional sources above to split.',
                              style: AppTypography.bodySmall(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxl),
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
