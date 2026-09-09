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

class AddIncomePage extends ConsumerStatefulWidget {
  const AddIncomePage({super.key});

  @override
  ConsumerState<AddIncomePage> createState() => _AddIncomePageState();
}

class _AddIncomePageState extends ConsumerState<AddIncomePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _noteController = TextEditingController();
  
  String? _selectedSourceId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSourceId == null) {
      AppFeedback.showError(context, context.tr('select_destination_source'));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final amount = MoneyFormatter.parseToMinor(_amountController.text) ?? 0;
      
      final result = await repo.recordIncome(
        amountMinor: amount,
        sourceId: _selectedSourceId!,
        description: _descController.text.trim().isEmpty ? context.tr('income') : _descController.text.trim(),
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('add_income')),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveIncome,
            child: Text(
              context.tr('save'),
              style: AppTypography.labelLarge(color: AppColors.income),
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

          // Default selection if null
          _selectedSourceId ??= sources.first.id;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount Input
                  Center(
                    child: SizedBox(
                      width: 200,
                      child: TextFormField(
                        controller: _amountController,
                        style: AppTypography.moneyLarge(color: AppColors.income),
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
                      labelText: context.tr('title_description'),
                      hintText: context.tr('income_origin_hint'),
                      prefixIcon: const Icon(LucideIcons.alignLeft),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Source Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSourceId,
                    decoration: InputDecoration(
                      labelText: context.tr('to_source'),
                      prefixIcon: const Icon(LucideIcons.arrowDownToLine, color: AppColors.income),
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

                  // Notes
                  TextFormField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: context.tr('note_optional'),
                      hintText: context.tr('extra_details_hint'),
                      prefixIcon: const Icon(LucideIcons.stickyNote),
                    ),
                    maxLines: 2,
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
