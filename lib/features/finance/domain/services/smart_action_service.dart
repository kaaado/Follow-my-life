import 'package:follow_my_life/features/finance/domain/entities/financial_snapshot.dart';
import 'package:follow_my_life/features/finance/domain/services/spending_anomaly_service.dart';
import 'package:follow_my_life/features/finance/domain/services/subscription_intelligence_service.dart';

enum ActionPriority { critical, important, recommended, optional }

class SmartActionItem {
  final String id;
  final String titleKey;
  final String descriptionKey;
  final String? directTitle; // For dynamic anomalies
  final String? directDescription;
  final ActionPriority priority;
  final String actionType; // 'pay_debt', 'apply_split', 'view_anomaly', 'review_plan', 'view_budget'
  final String routeName;
  final Map<String, dynamic>? arguments;

  const SmartActionItem({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    this.directTitle,
    this.directDescription,
    required this.priority,
    required this.actionType,
    required this.routeName,
    this.arguments,
  });
}

class SmartActionService {
  static List<SmartActionItem> generateActions({
    required FinancialSnapshot snapshot,
    required List<SpendingAnomaly> anomalies,
    required SubscriptionSummary subscriptionSummary,
  }) {
    final actions = <SmartActionItem>[];

    // 1. Critical Actions
    if (snapshot.upcomingCommitmentsMinor > snapshot.availableBalanceMinor) {
      actions.add(const SmartActionItem(
        id: 'critical_commitments',
        titleKey: 'action_cash_deficit_title',
        descriptionKey: 'action_cash_deficit_desc',
        priority: ActionPriority.critical,
        actionType: 'view_forecast',
        routeName: '/forecast',
      ));
    }

    if (snapshot.budgetHealth == 'exceeded') {
      actions.add(const SmartActionItem(
        id: 'critical_budget',
        titleKey: 'action_budget_exceeded_title',
        descriptionKey: 'action_budget_exceeded_desc',
        priority: ActionPriority.critical,
        actionType: 'view_budget',
        routeName: '/budgets',
      ));
    }

    // 2. Important Actions
    if (snapshot.virtualAllocationsMinor > 0) {
      actions.add(const SmartActionItem(
        id: 'important_virtual_split',
        titleKey: 'action_split_pending_title',
        descriptionKey: 'action_split_pending_desc',
        priority: ActionPriority.important,
        actionType: 'apply_split',
        routeName: '/virtual-splits',
      ));
    }

    if (subscriptionSummary.upcomingSubscriptions.isNotEmpty) {
      final firstSub = subscriptionSummary.upcomingSubscriptions.first;
      if (firstSub.nextDaysLeft <= 5) {
        actions.add(SmartActionItem(
          id: 'important_sub_${firstSub.item.id}',
          titleKey: 'action_sub_renewal_title',
          descriptionKey: 'action_sub_renewal_title',
          directDescription: '${firstSub.item.description} (${firstSub.nextDaysLeft}d)',
          priority: ActionPriority.important,
          actionType: 'view_recurring',
          routeName: '/recurring',
        ));
      }
    }

    // 3. Recommended Actions
    if (snapshot.netCashFlowMinor > 5000000 && snapshot.activePlansCount > 0) {
      actions.add(const SmartActionItem(
        id: 'rec_plan_boost',
        titleKey: 'action_plan_boost_title',
        descriptionKey: 'action_plan_boost_desc',
        priority: ActionPriority.recommended,
        actionType: 'review_plan',
        routeName: '/plan',
      ));
    }

    // 4. Optional Actions
    if (anomalies.isNotEmpty) {
      actions.add(SmartActionItem(
        id: 'opt_anomaly_${anomalies.first.id}',
        titleKey: '',
        descriptionKey: '',
        directTitle: anomalies.first.title,
        directDescription: anomalies.first.description,
        priority: ActionPriority.optional,
        actionType: 'view_anomaly',
        routeName: '/reports',
      ));
    }

    // Sort by priority
    actions.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    return actions;
  }
}
