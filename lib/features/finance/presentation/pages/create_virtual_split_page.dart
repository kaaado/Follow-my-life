import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/database/app_database.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/core/widgets/glass_card.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:follow_my_life/features/finance/domain/services/virtual_split_template_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CreateVirtualSplitPage extends ConsumerStatefulWidget {
  const CreateVirtualSplitPage({super.key});

  @override
  ConsumerState<CreateVirtualSplitPage> createState() => _CreateVirtualSplitPageState();
}

class _CreateVirtualSplitPageState extends ConsumerState<CreateVirtualSplitPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedSourceId;

  final List<({TextEditingController amountCtrl, String? categoryId, TextEditingController noteCtrl})> _items = [];

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  void _addItem() {
    setState(() {
      _items.add((
        amountCtrl: TextEditingController(),
        categoryId: null,
        noteCtrl: TextEditingController(),
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  void _applyTemplate(VirtualSplitPresetTemplate template, int availableBalance, List<Category> categories) {
    _nameController.text = template.getName(context);
    for (final item in _items) {
      item.amountCtrl.dispose();
      item.noteCtrl.dispose();
    }
    _items.clear();

    final itemSpecs = template.items.map((i) => (label: context.tr(i.categoryNameKey), percentage: i.percentage)).toList();
    final allocs = VirtualSplitTemplateService.calculatePercentageAllocations(
      totalBalanceMinor: availableBalance,
      percentageItems: itemSpecs,
    );

    for (int i = 0; i < allocs.length; i++) {
      final alloc = allocs[i];
      final templateItem = template.items[i];
      final localizedItemName = context.tr(templateItem.categoryNameKey);

      Category? matchedCat;
      if (categories.isNotEmpty) {
        matchedCat = categories.firstWhere(
          (c) => c.id == templateItem.categoryIdHint || c.name.toLowerCase().contains(localizedItemName.toLowerCase().split(' ').first),
          orElse: () => categories[i % categories.length],
        );
      }

      final amountCtrl = TextEditingController(text: (alloc.amountMinor / 100.0).toStringAsFixed(2));
      final noteCtrl = TextEditingController(text: '$localizedItemName (${alloc.percentage.toInt()}%)');

      _items.add((
        amountCtrl: amountCtrl,
        categoryId: matchedCat?.id,
        noteCtrl: noteCtrl,
      ));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final item in _items) {
      item.amountCtrl.dispose();
      item.noteCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(activeSourcesProvider);
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sources = sourcesAsync.valueOrNull ?? [];
    final categories = categoriesAsync.valueOrNull ?? [];

    if (_selectedSourceId == null && sources.isNotEmpty) {
      _selectedSourceId = sources.first.id;
    }

    final selectedSource = sources.where((s) => s.id == _selectedSourceId).firstOrNull ?? (sources.isNotEmpty ? sources.first : null);

    final currency = selectedSource?.currency ?? 'DZD';
    final availableBalance = selectedSource?.cachedBalanceMinor ?? 0;

    int currentTotalMinor = 0;
    for (final item in _items) {
      final val = double.tryParse(item.amountCtrl.text) ?? 0.0;
      currentTotalMinor += (val * 100).round();
    }

    final remainingUnallocated = availableBalance - currentTotalMinor;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('create_split')),
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            // Split Name Input
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr('split_name'),
                prefixIcon: const Icon(LucideIcons.tag),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a split name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Select Source Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedSourceId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('source'),
                prefixIcon: const Icon(LucideIcons.wallet),
              ),
              items: sources.map((s) {
                return DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    '${s.name} (${MoneyFormatter.format(s.cachedBalanceMinor, currency: s.currency)})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedSourceId = val;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Live Allocation Summary Banner
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('original_balance'),
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          MoneyFormatter.format(availableBalance, currency: currency),
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('allocated'),
                          style: AppTypography.bodyMedium(color: AppColors.tertiary),
                        ),
                        Text(
                          MoneyFormatter.format(currentTotalMinor, currency: currency),
                          style: AppTypography.bodyMedium(color: AppColors.tertiary).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Divider(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, height: 1),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('remaining_unallocated'),
                          style: AppTypography.bodyMedium(
                            color: remainingUnallocated >= 0 ? AppColors.income : AppColors.expense,
                          ),
                        ),
                        Text(
                          MoneyFormatter.format(remainingUnallocated, currency: currency),
                          style: AppTypography.bodyMedium(
                            color: remainingUnallocated >= 0 ? AppColors.income : AppColors.expense,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Preset Templates Selector Chips
            Text(
              context.tr('templates').toUpperCase(),
              style: AppTypography.labelSmall(
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: VirtualSplitTemplateService.templates.map((tmpl) {
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ActionChip(
                      avatar: Icon(LucideIcons.sparkles, size: 14, color: Theme.of(context).colorScheme.primary),
                      label: Text(tmpl.getName(context)),
                      onPressed: () => _applyTemplate(tmpl, availableBalance, categories),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('virtual_splits'),
                  style: AppTypography.headlineSmall(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: Text(context.tr('add_category')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Itemized Split Fields
            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: item.categoryId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: context.tr('category'),
                                  prefixIcon: const Icon(LucideIcons.tag),
                                ),
                                items: categories.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat.id,
                                    child: Text(cat.name, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _items[idx] = (
                                      amountCtrl: item.amountCtrl,
                                      categoryId: val,
                                      noteCtrl: item.noteCtrl,
                                    );
                                  });
                                },
                              ),
                            ),
                            if (_items.length > 1)
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, color: AppColors.expense),
                                onPressed: () => _removeItem(idx),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: item.amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: context.tr('amount'),
                            prefixIcon: const Icon(LucideIcons.banknote),
                            suffixText: currency,
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return context.tr('enter_amount');
                            }
                            final d = double.tryParse(val);
                            if (d == null || d <= 0) {
                              return context.tr('invalid_amount');
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: AppSpacing.xl),

            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                if (_selectedSourceId == null) return;

                if (remainingUnallocated < 0) {
                  AppFeedback.showError(context, context.tr('split_exceeds_balance'));
                  return;
                }

                final payloadItems = <({String categoryId, int amountMinor, String? note})>[];
                for (final item in _items) {
                  if (item.categoryId == null) {
                    AppFeedback.showError(context, context.tr('select_category_required'));
                    return;
                  }
                  final amount = double.parse(item.amountCtrl.text);
                  payloadItems.add((
                    categoryId: item.categoryId!,
                    amountMinor: (amount * 100).round(),
                    note: item.noteCtrl.text.isEmpty ? null : item.noteCtrl.text,
                  ));
                }

                final repo = ref.read(virtualSplitRepositoryProvider);
                await repo.createVirtualSplit(
                  name: _nameController.text.trim(),
                  sourceId: _selectedSourceId!,
                  items: payloadItems,
                  currency: currency,
                );

                if (context.mounted) {
                  AppFeedback.showSuccess(context, context.tr('split_created'));
                  context.pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(AppSpacing.md),
              ),
              child: Text(context.tr('save')),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
