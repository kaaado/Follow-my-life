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

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  String? _fromSourceId;
  String? _toSourceId;
  DateTime _date = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_fromSourceId == null || _toSourceId == null) {
      AppFeedback.showError(context, context.tr('please_select_both_sources'));
      return;
    }

    if (_fromSourceId == _toSourceId) {
      AppFeedback.showError(context, context.tr('same_source_error'));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final amount = MoneyFormatter.parseToMinor(_amountController.text) ?? 0;
      
      final result = await repo.recordTransfer(
        fromSourceId: _fromSourceId!,
        toSourceId: _toSourceId!,
        amountMinor: amount,
        date: _date,
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
        title: Text(context.tr('transfer')),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveTransfer,
            child: Text(
              context.tr('save'),
              style: AppTypography.labelLarge(color: AppColors.transfer),
            ),
          ),
        ],
      ),
      body: sourcesAsync.when(
        data: (sources) {
          if (sources.length < 2) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.arrowRightLeft, size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: AppSpacing.md),
                  Text(context.tr('need_2_sources')),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => context.pushReplacement('/add-source'),
                    child: Text(context.tr('add_source')),
                  ),
                ],
              ),
            );
          }

          if (_fromSourceId == null && sources.isNotEmpty) _fromSourceId = sources[0].id;
          if (_toSourceId == null && sources.length > 1) _toSourceId = sources[1].id;

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
                        style: AppTypography.moneyLarge(color: AppColors.transfer),
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
                  
                  // From Source
                  DropdownButtonFormField<String>(
                    initialValue: _fromSourceId,
                    decoration: InputDecoration(
                      labelText: context.tr('from'),
                      prefixIcon: const Icon(LucideIcons.logOut, color: AppColors.expense),
                    ),
                    items: sources.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _fromSourceId = val);
                    },
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // To Source
                  DropdownButtonFormField<String>(
                    initialValue: _toSourceId,
                    decoration: InputDecoration(
                      labelText: context.tr('to'),
                      prefixIcon: const Icon(LucideIcons.logIn, color: AppColors.income),
                    ),
                    items: sources.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _toSourceId = val);
                    },
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.tr('date'),
                        prefixIcon: const Icon(LucideIcons.calendar),
                      ),
                      child: Text(DateHelper.formatDate(_date)),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Note
                  TextFormField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: context.tr('note_optional'),
                      prefixIcon: const Icon(LucideIcons.stickyNote),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(context.tr('error_loading_sources'))),
      ),
    );
  }
}
