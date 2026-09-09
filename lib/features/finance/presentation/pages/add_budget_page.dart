import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddBudgetPage extends ConsumerStatefulWidget {
  const AddBudgetPage({super.key});

  @override
  ConsumerState<AddBudgetPage> createState() => _AddBudgetPageState();
}

class _AddBudgetPageState extends ConsumerState<AddBudgetPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _period = 'monthly';
  String? _selectedCategoryId;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(budgetRepositoryProvider);
      final amount = MoneyFormatter.parseToMinor(_amountController.text) ?? 0;
      
      final now = DateTime.now();
      final result = await repo.createBudget(
        amountMinor: amount,
        categoryId: _selectedCategoryId ?? 'cat_other',
        year: now.year,
        month: now.month,
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
    final categoriesAsync = ref.watch(activeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('create_budget')),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/budgets'),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveBudget,
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
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.tr('budget_name'),
                  prefixIcon: const Icon(LucideIcons.pieChart),
                  hintText: context.tr('budget_name_hint'),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter name' : null,
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: context.tr('limit_amount'),
                  prefixIcon: const Icon(LucideIcons.coins),
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
                initialValue: _period,
                decoration: InputDecoration(
                  labelText: context.tr('period'),
                  prefixIcon: const Icon(LucideIcons.calendar),
                ),
                items: [
                  DropdownMenuItem(value: 'weekly', child: Text(context.tr('weekly'))),
                  DropdownMenuItem(value: 'monthly', child: Text(context.tr('monthly'))),
                  DropdownMenuItem(value: 'yearly', child: Text(context.tr('yearly'))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _period = val);
                },
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) return const SizedBox.shrink();
                  
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: context.tr('link_category_optional'),
                      prefixIcon: const Icon(LucideIcons.tag),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(context.tr('none_general_budget'))),
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
