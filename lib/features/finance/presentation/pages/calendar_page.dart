import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/utils/money_formatter.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focusedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final debtsAsync = ref.watch(activeDebtsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: Text(context.tr('calendar')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Header Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: () {
                    setState(() {
                      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
                    });
                  },
                ),
                Text(
                  '${_monthName(_focusedDate.month)} ${_focusedDate.year}',
                  style: AppTypography.headlineMedium(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight),
                  onPressed: () {
                    setState(() {
                      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              context.tr('upcoming_events'),
              style: AppTypography.headlineSmall(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Combine recurring + debt due dates
            recurringAsync.when(
              data: (recurringList) {
                return debtsAsync.when(
                  data: (debtList) {
                    final events = <Widget>[];

                    // Recurring items
                    for (final rec in recurringList) {
                      events.add(
                        Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          child: ListTile(
                            leading: Icon(
                              rec.type == 'income' ? LucideIcons.arrowDownToLine : LucideIcons.repeat,
                              color: rec.type == 'income' ? AppColors.income : AppColors.expense,
                            ),
                            title: Text(
                              rec.description,
                              style: AppTypography.bodyMedium(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${context.tr('frequency')}: ${rec.frequency.toUpperCase()}',
                              style: AppTypography.bodySmall(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            trailing: Text(
                              MoneyFormatter.format(rec.amountMinor),
                              style: AppTypography.labelLarge(
                                color: rec.type == 'income' ? AppColors.income : AppColors.expense,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    // Debts with due date in focused month
                    for (final debt in debtList) {
                      if (debt.dueDate != null &&
                          debt.dueDate!.year == _focusedDate.year &&
                          debt.dueDate!.month == _focusedDate.month) {
                        final remaining = debt.amountMinor - debt.paidAmountMinor;
                        events.add(
                          Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            child: ListTile(
                              leading: Icon(
                                debt.type == 'i_owe' ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
                                color: AppColors.warning,
                              ),
                              title: Text(
                                '${context.tr('debt')}: ${debt.personName}',
                                style: AppTypography.bodyMedium(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${context.tr('due_on')}: ${debt.dueDate!.day}/${debt.dueDate!.month}/${debt.dueDate!.year}',
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              trailing: Text(
                                MoneyFormatter.format(remaining),
                                style: AppTypography.labelLarge(color: AppColors.warning),
                              ),
                            ),
                          ),
                        );
                      }
                    }

                    if (events.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Center(
                          child: Text(
                            context.tr('no_events_month'),
                            style: AppTypography.bodyMedium(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(children: events);
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => Text(context.tr('error_loading_debts')),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text(context.tr('error_loading_recurring')),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[(month - 1).clamp(0, 11)];
  }
}
