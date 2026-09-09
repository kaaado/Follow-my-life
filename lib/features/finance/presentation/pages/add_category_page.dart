import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddCategoryPage extends ConsumerStatefulWidget {
  const AddCategoryPage({super.key});

  @override
  ConsumerState<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends ConsumerState<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String _selectedType = 'expense';
  int _selectedColorIndex = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(categoryRepositoryProvider);
      
      final result = await repo.createCategory(
        name: _nameController.text.trim(),
        colorIndex: _selectedColorIndex,
        icon: 'tag',
      );

      result.when(
        success: (_) {
          if (mounted) context.pop();
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
        title: Text(context.tr('add_category')),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/categories'),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveCategory,
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
                  labelText: context.tr('category_name'),
                  prefixIcon: const Icon(LucideIcons.tag),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (val) => val == null || val.trim().isEmpty ? context.tr('enter_name') : null,
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: context.tr('type'),
                  prefixIcon: const Icon(LucideIcons.layers),
                ),
                items: [
                  DropdownMenuItem(value: 'expense', child: Text(context.tr('expense'))),
                  DropdownMenuItem(value: 'income', child: Text(context.tr('income'))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              
              const SizedBox(height: AppSpacing.xxl),
              
              Text(
                'Color',
                style: AppTypography.labelLarge(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              
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
}
