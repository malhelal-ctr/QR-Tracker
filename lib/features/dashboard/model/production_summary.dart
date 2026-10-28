import '../../../core/data/models.dart';
import '../../../core/utils/format.dart';

/// One logged day inside the summary period.
class SummaryDay {
  const SummaryDay({required this.date, required this.printed, this.target});

  final DateTime date;
  final int printed;
  final int? target;

  bool get goalMet => target != null && target! > 0 && printed >= target!;
}

/// Daily log totals for a date range (inclusive). Only days with a logged counter count,
/// so days not yet logged don't inflate the target.
class ProductionSummary {
  const ProductionSummary({required this.from, required this.to, required this.days});

  factory ProductionSummary.compute({required Iterable<Day> days, required int? defaultTarget, required DateTime from, required DateTime to}) {
    final start = ymd(from);
    final end = ymd(to);
    final inRange = days.where((d) => d.counter != null && d.date.compareTo(start) >= 0 && d.date.compareTo(end) <= 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return ProductionSummary(
      from: from,
      to: to,
      days: [for (final d in inRange) SummaryDay(date: DateTime.parse(d.date), printed: d.counter!, target: d.target ?? defaultTarget)],
    );
  }

  final DateTime from;
  final DateTime to;

  /// Logged days in the period, oldest first.
  final List<SummaryDay> days;

  int get printed => days.fold(0, (a, d) => a + d.printed);

  /// Sum of the targets of the logged days that have one.
  int get target => days.fold(0, (a, d) => a + (d.target ?? 0));

  bool get hasTarget => days.any((d) => d.target != null);

  int get difference => printed - target;

  int get average => days.isEmpty ? 0 : (printed / days.length).round();

  int get goalMetDays => days.where((d) => d.goalMet).length;

  int get daysWithTarget => days.where((d) => d.target != null).length;

  SummaryDay? get bestDay => days.isEmpty ? null : days.reduce((a, b) => b.printed > a.printed ? b : a);
}
