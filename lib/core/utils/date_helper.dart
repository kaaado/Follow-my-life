/// Date formatting and helper utilities.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';

class DateHelper {
  DateHelper._();

  static String formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);
  static String formatShortDate(DateTime date) => DateFormat('MMM d').format(date);
  static String formatFullDate(DateTime date) => DateFormat('EEEE, MMM d, yyyy').format(date);
  static String formatMonthYear(DateTime date) => DateFormat('MMMM yyyy').format(date);
  static String formatTime(DateTime date) => DateFormat('HH:mm').format(date);

  static String relativeDate(DateTime date, [BuildContext? context]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return context != null ? context.tr('today') : 'Today';
    if (diff == 1) return context != null ? context.tr('tomorrow') : 'Tomorrow';
    if (diff == -1) return context != null ? context.tr('yesterday') : 'Yesterday';
    return formatDate(date);
  }

  static DateTime startOfMonth([DateTime? date]) {
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month, 1);
  }

  static DateTime endOfMonth([DateTime? date]) {
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month + 1, 0, 23, 59, 59);
  }

  static DateTime startOfWeek([DateTime? date]) {
    final d = date ?? DateTime.now();
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static String greetingMessage([BuildContext? context]) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context != null ? context.tr('good_morning') : 'Good morning';
    if (hour < 17) return context != null ? context.tr('good_afternoon') : 'Good afternoon';
    return context != null ? context.tr('good_evening') : 'Good evening';
  }
}
