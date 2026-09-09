import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddSourcePage extends ConsumerStatefulWidget {
  const AddSourcePage({super.key});

  @override
  ConsumerState<AddSourcePage> createState() => _AddSourcePageState();
}

class _AddSourcePageState extends ConsumerState<AddSourcePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  
  SourceType _selectedType = SourceType.cash;
  String _selectedIcon = 'wallet';
  int _selectedColorIndex = 0;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'wallet', 'icon': LucideIcons.wallet},
    {'name': 'banknote', 'icon': LucideIcons.banknote},
    {'name': 'creditCard', 'icon': LucideIcons.creditCard},
    {'name': 'building', 'icon': LucideIcons.building},
    {'name': 'smartphone', 'icon': LucideIcons.smartphone},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _saveSource() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(sourceRepositoryProvider);
      
      final initialBalance = MoneyFormatter.parseToMinor(_balanceController.text) ?? 0;
      
      final result = await repo.createSource(
        name: _nameController.text.trim(),
        type: _selectedType,
        icon: _selectedIcon,
        colorIndex: _selectedColorIndex,
        initialBalanceMinor: initialBalance,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/sources'),
        ),
        title: Text(context.tr('add_source')),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSource,
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
              Text(
                context.tr('source_details'),
                style: AppTypography.headlineSmall(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              
              TextFormField(
                controller: _nameController,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'^\s+')),
                ],
                decoration: InputDecoration(
                  labelText: context.tr('source_name'),
                  hintText: context.tr('source_name_hint'),
                  prefixIcon: const Icon(LucideIcons.type),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? context.tr('amount_required') : null,
                textCapitalization: TextCapitalization.words,
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              DropdownButtonFormField<SourceType>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: context.tr('type'),
                  prefixIcon: const Icon(LucideIcons.layers),
                ),
                items: SourceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getTypeName(context, type)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              TextFormField(
                controller: _balanceController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: context.tr('initial_balance'),
                  hintText: '0.00',
                  prefixIcon: const Icon(LucideIcons.coins),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    final parsed = MoneyFormatter.parseToMinor(val);
                    if (parsed == null) return context.tr('amount_positive');
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: AppSpacing.xxl),
              
              Text(
                context.tr('theme_mode'),
                style: AppTypography.headlineSmall(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Icon selector
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _iconOptions.length,
                  itemBuilder: (context, index) {
                    final option = _iconOptions[index];
                    final isSelected = _selectedIcon == option['name'];
                    
                    final primaryColor = Theme.of(context).colorScheme.primary;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = option['name']),
                      child: Container(
                        width: 60,
                        margin: const EdgeInsets.only(right: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? primaryColor.withValues(alpha: 0.1) 
                              : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          option['icon'] as IconData,
                          color: isSelected ? primaryColor : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              // Color selector
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppColors.categoryColors.length,
                  itemBuilder: (context, index) {
                    final color = AppColors.categoryColors[index];
                    final isSelected = _selectedColorIndex == index;
                    
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorIndex = index),
                      child: Container(
                        width: 48,
                        margin: const EdgeInsets.only(right: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                          boxShadow: isSelected ? [
                            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)
                          ] : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeName(BuildContext context, SourceType type) {
    switch (type) {
      case SourceType.cash: return context.tr('cash');
      case SourceType.bankAccount: return context.tr('bank_account');
      case SourceType.eWallet: return context.tr('e_wallet');
      case SourceType.incomeSource: return context.tr('income_source');
      case SourceType.other: return context.tr('other');
    }
  }
}
