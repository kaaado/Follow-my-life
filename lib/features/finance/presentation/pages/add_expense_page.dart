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
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
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
  
  String? _selectedSourceId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSourceId == null) {
      AppFeedback.showError(context, context.tr('need_source_first'));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final amount = MoneyFormatter.parseToMinor(_amountController.text) ?? 0;
      
      final result = await repo.recordExpense(
        amountMinor: amount,
        sourceId: _selectedSourceId!,
        categoryId: _selectedCategoryId,
        description: _descController.text.trim().isEmpty ? context.tr('expense') : _descController.text.trim(),
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
            onPressed: _isLoading ? null : _saveExpense,
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
                      width: 200,
                      child: TextFormField(
                        controller: _amountController,
                        style: AppTypography.moneyLarge(color: AppColors.expense),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: AppTypography.moneyLarge(color: isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.isEmpty) return context.tr('amount_required');
                          final parsed = MoneyFormatter.parseToMinor(val);
                          if (parsed == null || parsed <= 0) return context.tr('amount_positive');
                          return null;
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xxxl),
                  
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
                  
                  // Source
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSourceId,
                    decoration: InputDecoration(
                      labelText: context.tr('paid_from'),
                      prefixIcon: const Icon(LucideIcons.arrowUpFromLine, color: AppColors.expense),
                    ),
                    items: sources.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSourceId = val);
                    },
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
