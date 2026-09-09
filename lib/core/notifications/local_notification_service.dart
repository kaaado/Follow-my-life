import 'package:flutter/foundation.dart';
import 'package:follow_my_life/core/database/app_database.dart';

class FinancialNotification {
  final String id;
  final String title;
  final String body;
  final DateTime scheduledDate;
  final String type; // 'bill_due', 'low_balance', 'plan_milestone'
  final bool isRead;

  const FinancialNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.type,
    this.isRead = false,
  });
}

class LocalNotificationService {
  static final List<FinancialNotification> _inMemoryQueue = [];

  static List<FinancialNotification> get pendingNotifications => List.unmodifiable(_inMemoryQueue);

  static void evaluateScheduledReminders({
    required List<RecurringTransaction> recurring,
    required List<PlannedPurchase> plans,
    required int availableBalanceMinor,
  }) {
    _inMemoryQueue.clear();
    final now = DateTime.now();

    // 1. Recurring Bills Reminders
    for (final rec in recurring) {
      if (rec.isActive && rec.type == 'expense') {
        final daysLeft = rec.nextOccurrence.difference(now).inDays;
        if (daysLeft >= 0 && daysLeft <= 3) {
          _inMemoryQueue.add(FinancialNotification(
            id: 'notif_rec_${rec.id}',
            title: 'Upcoming Bill Due Soon',
            body: '${rec.description} (${rec.amountMinor ~/ 100} DZD) is due in $daysLeft day(s).',
            scheduledDate: rec.nextOccurrence,
            type: 'bill_due',
          ));
        }
      }
    }

    // 2. Low Available Balance Alert
    if (availableBalanceMinor < 100000) {
      // < 1,000 DZD
      _inMemoryQueue.add(FinancialNotification(
        id: 'notif_low_bal',
        title: 'Low Available Balance',
        body: 'Your available balance is low (${availableBalanceMinor ~/ 100} DZD). Avoid non-essential expenses.',
        scheduledDate: now,
        type: 'low_balance',
      ));
    }

    // 3. Plan Milestones
    for (final plan in plans) {
      if (plan.status != 'completed' && plan.status != 'cancelled') {
        if (plan.estimatedAmountMinor > 0) {
          final progress = plan.reservedAmountMinor / plan.estimatedAmountMinor;
          if (progress >= 0.8 && progress < 1.0) {
            _inMemoryQueue.add(FinancialNotification(
              id: 'notif_plan_${plan.id}',
              title: 'Goal Almost Complete!',
              body: '${plan.name} is ${ (progress * 100).round() }% reserved! Almost there.',
              scheduledDate: now,
              type: 'plan_milestone',
            ));
          }
        }
      }
    }

    debugPrint('Evaluated ${_inMemoryQueue.length} offline financial notifications.');
  }
}
