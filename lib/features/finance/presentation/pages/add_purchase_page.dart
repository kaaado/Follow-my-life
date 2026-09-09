import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/utils/date_helper.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddPurchasePage extends ConsumerStatefulWidget {
  const AddPurchasePage({super.key});

  @override
  ConsumerState<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends ConsumerState<AddPurchasePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _priority = 'medium';
  DateTime? _targetDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(purchaseRepositoryProvider);
      final amount = MoneyFormatter.parseToMinor(_amountController.text) ?? 0;
      
      final result = await repo.createPurchase(
        name: _nameController.text.trim(),
        estimatedAmountMinor: amount,
        priority: _priority,
        targetDate: _targetDate,
      );

      result.when(
        success: (_) {
          if (mounted) context.pop();
        },
        failure: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.message)),
            );
          }
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('plan_purchase')),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/plan'),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _savePurchase,
            child: Text(
              context.tr('save'),
              style: AppTypography.labelLarge(color: Theme.of(context).colorScheme.primary),
            ),
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
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.tr('purchase_name_label'),
                  prefixIcon: Icon(LucideIcons.shoppingCart),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter item name' : null,
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: context.tr('estimated_cost'),
                  prefixIcon: Icon(LucideIcons.coins),
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter amount';
                  final parsed = MoneyFormatter.parseToMinor(val);
                  if (parsed == null || parsed <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: InputDecoration(
                  labelText: context.tr('priority'),
                  prefixIcon: Icon(LucideIcons.flag),
                ),
                items: [
                  DropdownMenuItem(value: 'low', child: Text(context.tr('priority_low'))),
                  DropdownMenuItem(value: 'medium', child: Text(context.tr('priority_medium'))),
                  DropdownMenuItem(value: 'high', child: Text(context.tr('priority_high'))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _priority = val);
                },
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _targetDate = date);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('target_date_optional'),
                    prefixIcon: Icon(LucideIcons.calendar),
                  ),
                  child: Text(_targetDate != null ? DateHelper.formatDate(_targetDate!) : 'Not set'),
                ),
              ),
              
              if (_targetDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _targetDate = null),
                    icon: const Icon(LucideIcons.xCircle, size: 16),
                    label: Text(context.tr('clear_date')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
