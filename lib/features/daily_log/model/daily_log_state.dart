import '../../../core/data/models.dart';
import '../../../core/data/month_plan.dart';

/// How the month is shown: a calendar, a table of the days, or the machine total history.
enum LogView { calendar, list, machine }

/// What the entry panel needs for one production day.
class LogEntry {
  const LogEntry({
    required this.date,
    this.log,
    this.previousTotal,
    this.previousTotalDate,
    this.monthTarget,
    this.off = false,
    this.product = '',
    this.holiday,
  });

  /// Name of the holiday on this day, if it is one.
  final String? holiday;

  /// yyyy-MM-dd
  final String date;

  /// The day's log, null when nothing is logged yet.
  final Day? log;

  /// The machine total logged before this day, and its date, to check this day's total against.
  final int? previousTotal;
  final String? previousTotalDate;

  /// The month's daily target (used when the day has no target of its own).
  final int? monthTarget;

  /// The day is marked as a day off.
  final bool off;

  /// Product to log under: the day's own, else the active list's.
  final String product;
}

class DailyLogState {
  const DailyLogState({
    required this.month,
    required this.summary,
    this.view = LogView.calendar,
    this.ownTarget = false,
    this.products = const [],
    this.selected,
  });

  /// First day of the month shown.
  final DateTime month;

  /// The month's days and totals.
  final MonthSummary summary;

  final LogView view;

  /// The month has its own daily target (not copied from an earlier month).
  final bool ownTarget;

  /// Saved products to pick from.
  final List<String> products;

  /// Day open in the entry panel (yyyy-MM-dd); null when the panel is closed.
  final String? selected;

  DailyLogState copyWith({
    DateTime? month,
    MonthSummary? summary,
    LogView? view,
    bool? ownTarget,
    List<String>? products,
    String? Function()? selected,
  }) => DailyLogState(
    month: month ?? this.month,
    summary: summary ?? this.summary,
    view: view ?? this.view,
    ownTarget: ownTarget ?? this.ownTarget,
    products: products ?? this.products,
    selected: selected == null ? this.selected : selected(),
  );
}
