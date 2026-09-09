import 'package:flutter/material.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';

class VirtualSplitPresetTemplate {
  final String id;
  final String nameKey;
  final String descriptionKey;
  final List<({String categoryNameKey, double percentage, String? categoryIdHint})> items;

  const VirtualSplitPresetTemplate({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.items,
  });

  String getName(BuildContext context) => context.tr(nameKey);
  String getDescription(BuildContext context) => context.tr(descriptionKey);
}

class VirtualSplitTemplateService {
  static const List<VirtualSplitPresetTemplate> templates = [
    VirtualSplitPresetTemplate(
      id: 'salary_50_20_20_10',
      nameKey: 'tmpl_salary_50_20_20_10',
      descriptionKey: 'tmpl_salary_50_20_20_10_desc',
      items: [
        (categoryNameKey: 'cat_needs_essentials', percentage: 50.0, categoryIdHint: 'cat_food'),
        (categoryNameKey: 'cat_savings_reserve', percentage: 20.0, categoryIdHint: 'cat_savings'),
        (categoryNameKey: 'cat_plans_goals', percentage: 20.0, categoryIdHint: 'cat_shopping'),
        (categoryNameKey: 'cat_free_spending', percentage: 10.0, categoryIdHint: 'cat_entertainment'),
      ],
    ),
    VirtualSplitPresetTemplate(
      id: 'classic_50_30_20',
      nameKey: 'tmpl_classic_50_30_20',
      descriptionKey: 'tmpl_classic_50_30_20_desc',
      items: [
        (categoryNameKey: 'cat_essential_needs', percentage: 50.0, categoryIdHint: 'cat_food'),
        (categoryNameKey: 'cat_personal_wants', percentage: 30.0, categoryIdHint: 'cat_entertainment'),
        (categoryNameKey: 'cat_savings_investments', percentage: 20.0, categoryIdHint: 'cat_savings'),
      ],
    ),
    VirtualSplitPresetTemplate(
      id: 'monthly_essentials',
      nameKey: 'tmpl_monthly_essentials',
      descriptionKey: 'tmpl_monthly_essentials_desc',
      items: [
        (categoryNameKey: 'cat_food_groceries', percentage: 40.0, categoryIdHint: 'cat_food'),
        (categoryNameKey: 'cat_utilities_bills', percentage: 30.0, categoryIdHint: 'cat_bills'),
        (categoryNameKey: 'cat_transport_fuel', percentage: 15.0, categoryIdHint: 'cat_transport'),
        (categoryNameKey: 'cat_emergency_buffer', percentage: 15.0, categoryIdHint: 'cat_savings'),
      ],
    ),
    VirtualSplitPresetTemplate(
      id: 'emergency_first',
      nameKey: 'tmpl_emergency_first',
      descriptionKey: 'tmpl_emergency_first_desc',
      items: [
        (categoryNameKey: 'cat_emergency_reserve', percentage: 50.0, categoryIdHint: 'cat_savings'),
        (categoryNameKey: 'cat_fixed_living', percentage: 30.0, categoryIdHint: 'cat_bills'),
        (categoryNameKey: 'cat_flexible_spending', percentage: 20.0, categoryIdHint: 'cat_shopping'),
      ],
    ),
    VirtualSplitPresetTemplate(
      id: 'debt_paydown',
      nameKey: 'tmpl_debt_paydown',
      descriptionKey: 'tmpl_debt_paydown_desc',
      items: [
        (categoryNameKey: 'cat_debt_repayment', percentage: 40.0, categoryIdHint: 'cat_bills'),
        (categoryNameKey: 'cat_living_essentials', percentage: 40.0, categoryIdHint: 'cat_food'),
        (categoryNameKey: 'cat_savings_reserve', percentage: 10.0, categoryIdHint: 'cat_savings'),
        (categoryNameKey: 'cat_emergency_buffer', percentage: 10.0, categoryIdHint: 'cat_savings'),
      ],
    ),
    VirtualSplitPresetTemplate(
      id: 'wealth_growth',
      nameKey: 'tmpl_wealth_growth',
      descriptionKey: 'tmpl_wealth_growth_desc',
      items: [
        (categoryNameKey: 'cat_investments_growth', percentage: 40.0, categoryIdHint: 'cat_savings'),
        (categoryNameKey: 'cat_core_expenses', percentage: 30.0, categoryIdHint: 'cat_food'),
        (categoryNameKey: 'cat_cash_reserve', percentage: 20.0, categoryIdHint: 'cat_savings'),
        (categoryNameKey: 'cat_lifestyle', percentage: 10.0, categoryIdHint: 'cat_entertainment'),
      ],
    ),
    VirtualSplitPresetTemplate(
      id: 'travel_vacation',
      nameKey: 'tmpl_travel_vacation',
      descriptionKey: 'tmpl_travel_vacation_desc',
      items: [
        (categoryNameKey: 'cat_lodging_hotel', percentage: 40.0, categoryIdHint: 'cat_travel'),
        (categoryNameKey: 'cat_flights_transit', percentage: 30.0, categoryIdHint: 'cat_transport'),
        (categoryNameKey: 'cat_activities_dining', percentage: 30.0, categoryIdHint: 'cat_food'),
      ],
    ),
    VirtualSplitPresetTemplate(
      id: 'student_freelancer',
      nameKey: 'tmpl_student_freelancer',
      descriptionKey: 'tmpl_student_freelancer_desc',
      items: [
        (categoryNameKey: 'cat_basic_survival', percentage: 60.0, categoryIdHint: 'cat_food'),
        (categoryNameKey: 'cat_work_study_tools', percentage: 20.0, categoryIdHint: 'cat_shopping'),
        (categoryNameKey: 'cat_future_buffer', percentage: 20.0, categoryIdHint: 'cat_savings'),
      ],
    ),
  ];

  /// Computes minor unit allocations from a total balance and percentage items.
  static List<({String label, int amountMinor, double percentage})> calculatePercentageAllocations({
    required int totalBalanceMinor,
    required List<({String label, double percentage})> percentageItems,
  }) {
    final result = <({String label, int amountMinor, double percentage})>[];
    int allocatedSum = 0;

    for (int i = 0; i < percentageItems.length; i++) {
      final item = percentageItems[i];
      if (i == percentageItems.length - 1) {
        // Last item absorbs remaining to avoid rounding drop
        final lastAmount = totalBalanceMinor - allocatedSum;
        result.add((label: item.label, amountMinor: lastAmount.clamp(0, totalBalanceMinor), percentage: item.percentage));
      } else {
        final amount = ((totalBalanceMinor * item.percentage) / 100.0).round();
        allocatedSum += amount;
        result.add((label: item.label, amountMinor: amount, percentage: item.percentage));
      }
    }

    return result;
  }
}
