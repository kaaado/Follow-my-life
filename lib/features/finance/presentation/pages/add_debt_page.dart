import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';

class AddDebtPage extends ConsumerStatefulWidget {
  const AddDebtPage({super.key});

  @override
  ConsumerState<AddDebtPage> createState() => _AddDebtPageState();
}

class _AddDebtPageState extends ConsumerState<AddDebtPage> {
  final _formKey = GlobalKey<FormState>();
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _type = 'i_owe'; // 'i_owe' or 'owed_to_me'
  DateTime? _dueDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('add_debt')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type Selector Toggle
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'i_owe',
                    label: Text(context.tr('i_owe_someone')),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: 'owed_to_me',
                    label: Text(context.tr('someone_owes_me')),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (set) {
                  setState(() {
                    _type = set.first;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Person Name
              TextFormField(
                controller: _personController,
                decoration: InputDecoration(
                  labelText: _type == 'i_owe' ? 'Creditor (Who you owe)' : 'Debtor (Who owes you)',
                  hintText: context.tr('debt_person_hint'),
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.tr('principal_amount'),
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter an amount';
                  final d = double.tryParse(val);
                  if (d == null || d <= 0) return 'Enter a valid positive number';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Due Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    setState(() {
                      _dueDate = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('repayment_date_label'),
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dueDate == null
                        ? 'No deadline set'
                        : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.tr('notes_optional'),
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveDebt,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  backgroundColor: _type == 'i_owe' ? AppColors.expense : AppColors.income,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _type == 'i_owe' ? 'Save Liability Record' : 'Save Receivable Record',
                        style: AppTypography.labelLarge(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final amtDouble = double.parse(_amountController.text.trim());
    final minor = (amtDouble * 100).round();

    final result = await ref.read(debtRepositoryProvider).createDebt(
          personName: _personController.text.trim(),
          type: _type,
          amountMinor: minor,
          dueDate: _dueDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.isSuccess) {
        AppFeedback.showSuccess(context, context.tr('debt_created'));
        context.pop();
      } else {
        AppFeedback.showError(context, result.failure.message);
      }
    }
  }
}
