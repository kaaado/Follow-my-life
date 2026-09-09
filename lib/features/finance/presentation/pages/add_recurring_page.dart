import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/utils/date_helper.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddRecurringPage extends ConsumerStatefulWidget {
  const AddRecurringPage({super.key});

  @override
  ConsumerState<AddRecurringPage> createState() => _AddRecurringPageState();
}

class _AddRecurringPageState extends ConsumerState<AddRecurringPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _type = 'expense';
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  String? _selectedSourceId;
  String? _selectedCategoryId;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveRecurring() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedSourceId == null) {
      AppFeedback.showError(context, context.tr('select_source'));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(recurringRepositoryProvider);
      final amount = MoneyFormatter.parseToMinor(_amountController.text) ?? 0;
      
      final result = await repo.createRecurring(
        description: _nameController.text.trim(),
        type: _type,
        amountMinor: amount,
        frequency: _frequency,
        startDate: _startDate,
        sourceId: _selectedSourceId ?? '',
        categoryId: _selectedCategoryId,
      );

      result.when(
        success: (_) {
          ref.invalidate(activeRecurringProvider);
          ref.invalidate(financialSummaryProvider);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('add_recurring')),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/recurring'),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveRecurring,
            child: Text(context.tr('save'), style: AppTypography.labelLarge(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Segmented Button (Expense / Income)
              Center(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'expense', label: Text(context.tr('expense'))),
                    ButtonSegment(value: 'income', label: Text(context.tr('income'))),
                  ],
                  selected: {_type},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => _type = newSelection.first);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return _type == 'expense' ? AppColors.expense.withOpacity(0.2) : AppColors.income.withOpacity(0.2);
                      }
                      return Colors.transparent;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return _type == 'expense' ? AppColors.expense : AppColors.income;
                      }
                      return Theme.of(context).colorScheme.onSurface;
                    }),
                  ),
                ),
              ),
              
              const SizedBox(height: AppSpacing.xxxl),
              
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _type == 'expense' ? context.tr('subscription_bill_name') : context.tr('income_name'),
                  prefixIcon: const Icon(LucideIcons.repeat),
                  hintText: _type == 'expense' ? 'e.g. Netflix, Rent' : 'e.g. Salary',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? context.tr('enter_name') : null,
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: context.tr('amount'),
                  prefixIcon: const Icon(LucideIcons.coins),
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return context.tr('amount_required');
                  final parsed = MoneyFormatter.parseToMinor(val);
                  if (parsed == null || parsed <= 0) return context.tr('amount_positive');
                  return null;
                },
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: InputDecoration(
                  labelText: context.tr('frequency'),
                  prefixIcon: const Icon(LucideIcons.calendarClock),
                ),
                items: [
                  DropdownMenuItem(value: 'daily', child: Text(context.tr('freq_daily'))),
                  DropdownMenuItem(value: 'weekly', child: Text(context.tr('freq_weekly'))),
                  DropdownMenuItem(value: 'monthly', child: Text(context.tr('freq_monthly'))),
                  DropdownMenuItem(value: 'yearly', child: Text(context.tr('freq_yearly'))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _frequency = val);
                },
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _startDate = date);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('next_date'),
                    prefixIcon: const Icon(LucideIcons.calendar),
                  ),
                  child: Text(DateHelper.formatDate(_startDate)),
                ),
              ),
              
              const SizedBox(height: AppSpacing.lg),

              sourcesAsync.when(
                data: (sources) {
                  if (sources.isEmpty) return const SizedBox.shrink();
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedSourceId,
                    hint: Text(context.tr('select_source')),
                    decoration: InputDecoration(
                      labelText: context.tr('auto_post_source'),
                      prefixIcon: const Icon(LucideIcons.wallet),
                    ),
                    items: sources.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    validator: (val) => val == null ? context.tr('select_source') : null,
                    onChanged: (val) => setState(() => _selectedSourceId = val),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (err, stack) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) return const SizedBox.shrink();
                  
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: context.tr('category'),
                      prefixIcon: const Icon(LucideIcons.tag),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(context.tr('all'))),
                      ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
