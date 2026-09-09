import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/core/widgets/app_empty_state.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('categories')),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showAddCategoryDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, ref),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return AppEmptyState(
              icon: LucideIcons.tag,
              title: context.tr('no_categories'),
              message: context.tr('categories'),
              actionLabel: context.tr('add_category'),
              onAction: () => _showAddCategoryDialog(context, ref),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              Text(
                context.tr('categories'),
                style: AppTypography.labelLarge(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...categories.map((c) => _buildCategoryTile(context, ref, c, isDark)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(context.tr('error_loading_categories'))),
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, WidgetRef ref, Category category, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Icon(LucideIcons.tag, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(
          context.tr(category.name),
          style: AppTypography.bodyLarge(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            LucideIcons.moreVertical,
            size: 18,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          onSelected: (val) {
            if (val == 'edit') {
              _showEditCategoryDialog(context, ref, category);
            } else if (val == 'delete') {
              _confirmDeleteCategory(context, ref, category);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(LucideIcons.edit2, size: 16),
                  const SizedBox(width: 8),
                  Text(context.tr('edit')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(context.tr('delete'), style: const TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('add_category')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('category_name'),
            prefixIcon: const Icon(LucideIcons.tag),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                final result = await ref.read(categoryRepositoryProvider).createCategory(name: text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  if (result.isSuccess) {
                    AppFeedback.showSuccess(context, context.tr('saved'));
                  } else {
                    AppFeedback.showError(context, result.failure.message);
                  }
                }
              }
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, Category category) {
    final ctrl = TextEditingController(text: context.tr(category.name));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('edit_category')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('category_name'),
            prefixIcon: const Icon(LucideIcons.tag),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                final result = await ref.read(categoryRepositoryProvider).updateCategory(
                      id: category.id,
                      name: text,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  if (result.isSuccess) {
                    AppFeedback.showSuccess(context, context.tr('saved'));
                  } else {
                    AppFeedback.showError(context, result.failure.message);
                  }
                }
              }
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_category')),
        content: Text(context.tr('delete_item_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              final result = await ref.read(categoryRepositoryProvider).archiveCategory(category.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                if (result.isSuccess) {
                  AppFeedback.showSuccess(context, context.tr('item_deleted'));
                } else {
                  AppFeedback.showError(context, result.failure.message);
                }
              }
            },
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
  }
}
