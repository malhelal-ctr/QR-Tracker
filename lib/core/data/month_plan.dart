import 'dart:math';

import '../utils/format.dart';
import 'models.dart';

/// 'yyyy-MM' key of the month [d] is in.
String ym(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Daily target for [month] ('yyyy-MM'): its own, else the latest earlier month's (a new month starts with
/// the plan of the month before), else [fallback] (the single daily target used before monthly targets).
int? monthDailyTarget(String month, Map<String, int> monthTargets, {int? fallback}) {
  if (monthTargets[month] case final t?) return t;
  final earlier = monthTargets.keys.where((k) => k.compareTo(month) < 0).toList()..sort();
  return earlier.isEmpty ? fallback : monthTargets[earlier.last];
}

/// Machine total check: how far [total] is from the previous total plus what was printed.
/// 0 = they agree; null when it can't be checked (a number is missing, or the total was reset).
int? totalGap({required int? previousTotal, required int? printed, required int? total, bool reset = false}) =>
    reset || previousTotal == null || printed == null || total == null ? null : total - (previousTotal + printed);

/// The latest machine total logged before [date] (yyyy-MM-dd), with its date.
({String date, int total})? previousTotal(String date, Iterable<Day> days) {
  Day? best;
  for (final d in days) {
    if (d.total != null && d.date.compareTo(date) < 0 && (best == null || d.date.compareTo(best.date) > 0)) best = d;
  }
  return best == null ? null : (date: best.date, total: best.total!);
}

/// One calendar day of a month in the Daily log.
class MonthDay {
  const MonthDay({
    required this.date,
    required this.key,
    this.day,
    this.target,
    this.off = false,
    this.counted = false,
    this.runningDiff,
    this.previousTotal,
    this.holiday,
  });

  final DateTime date;

  /// Name of the holiday on this day, if it is one.
  final String? holiday;

  /// yyyy-MM-dd
  final String key;

  /// The day's log (merged), null when nothing is logged.
  final Day? day;

  /// The day's own target, else the month's daily target; null on a day off (or when no target is set).
  final int? target;

  /// Marked as a day off: no target, it isn't a working day.
  final bool off;

  /// The day has passed (or is today and logged), so it counts in "so far" totals and a missing log is a miss.
  final bool counted;

  /// Printed − target added up from the 1st of the month to this day; null for days not [counted].
  final int? runningDiff;

  /// The machine total logged before this day, to check this day's total against.
  final int? previousTotal;

  int? get printed => day?.counter;
  bool get logged => day?.hasLog ?? false;

  /// A working day that has passed without a printed count.
  bool get missing => counted && !off && printed == null;

  /// Printed − target for a counted day (a missing day counts as 0 printed); null when there is nothing to compare.
  int? get diff {
    if (!counted || (target == null && printed == null)) return null;
    if (target == null) return null;
    return (printed ?? 0) - target!;
  }

  /// See [totalGap].
  int? get gap => totalGap(previousTotal: previousTotal, printed: printed, total: day?.total, reset: day?.totalReset ?? false);
}

/// One month of the Daily log: every day with its target and result, and the month's totals.
class MonthSummary {
  const MonthSummary({required this.month, required this.days, required this.dailyTarget, required this.today, this.machinePrinted, this.machineLogged});

  /// [days]: one merged log per date (yyyy-MM-dd → day). [dailyTarget]: the month's daily target.
  factory MonthSummary.compute({
    required DateTime month,
    required Map<String, Day> days,
    required int? dailyTarget,
    required bool Function(String date) isOff,
    String? Function(String date)? holidayOn,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final today = ymd(now);
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final firstKey = ymd(first);

    // machine totals in date order, to find each day's previous total in one pass
    final withTotal = days.values.where((d) => d.total != null).toList()..sort((a, b) => a.date.compareTo(b.date));
    int? totalBefore(String key) => withTotal.lastWhereOrNull((d) => d.date.compareTo(key) < 0)?.total;

    var running = 0;
    final list = <MonthDay>[];
    for (var i = 1; i <= count; i++) {
      final date = DateTime(month.year, month.month, i);
      final key = ymd(date);
      final day = days[key];
      final off = isOff(key);
      final target = day?.target ?? (off ? null : dailyTarget);
      final logged = day?.counter != null;
      final counted = key.compareTo(today) < 0 || (key == today && logged);
      final d = MonthDay(date: date, key: key, day: day, target: target, off: off, counted: counted, previousTotal: totalBefore(key));
      int? runningDiff;
      if (counted) {
        running += d.diff ?? (off ? (day?.counter ?? 0) : 0);
        runningDiff = running;
      }
      list.add(MonthDay(
        date: date,
        key: key,
        day: day,
        target: target,
        off: off,
        counted: counted,
        previousTotal: d.previousTotal,
        runningDiff: runningDiff,
        holiday: holidayOn?.call(key),
      ));
    }

    // what the machine total moved this month: last total in the month − last total before it,
    // unless the total was reset in between; compared with the printed counts logged over the same days
    int? machinePrinted, machineLogged;
    final base = withTotal.lastWhereOrNull((d) => d.date.compareTo(firstKey) < 0);
    final inMonth = withTotal.where((d) => d.date.startsWith(ym(first))).toList();
    if (base != null && inMonth.isNotEmpty && !inMonth.any((d) => d.totalReset)) {
      final last = inMonth.last;
      machinePrinted = last.total! - base.total!;
      machineLogged = list.where((d) => d.key.compareTo(last.date) <= 0).fold<int>(0, (a, d) => a + (d.printed ?? 0));
    }

    return MonthSummary(month: first, days: list, dailyTarget: dailyTarget, today: DateTime(now.year, now.month, now.day), machinePrinted: machinePrinted, machineLogged: machineLogged);
  }

  /// First day of the month.
  final DateTime month;

  /// Every day of the month, 1st first.
  final List<MonthDay> days;

  /// The month's daily target; null when none is set.
  final int? dailyTarget;

  /// Codes the machine total moved over the month; null when it can't be worked out.
  final int? machinePrinted;

  /// Printed counts logged over the same days as [machinePrinted].
  final int? machineLogged;

  /// [machinePrinted] − [machineLogged]: printing the daily logs don't account for.
  int? get unaccounted => machinePrinted == null ? null : machinePrinted! - machineLogged!;

  Iterable<MonthDay> get _working => days.where((d) => !d.off);

  int get workingDays => _working.length;

  /// Sum of every day's target; null when no day has one.
  int? get monthTarget => days.any((d) => d.target != null) ? days.fold<int>(0, (a, d) => a + (d.target ?? 0)) : null;

  int get printed => days.fold(0, (a, d) => a + (d.printed ?? 0));

  /// Target of the days that have passed.
  int get targetSoFar => days.where((d) => d.counted).fold(0, (a, d) => a + (d.target ?? 0));

  /// Printed − target over the days that have passed (missing days count as 0 printed).
  /// Null when the month has no target to compare with.
  int? get missSoFar => monthTarget == null ? null : days.lastWhereOrNull((d) => d.counted)?.runningDiff;

  /// Working days still to come (today included until it is logged).
  int get workingDaysLeft => _working.where((d) => !d.counted && !d.date.isBefore(_today)).length;

  /// Start of the day the summary was worked out on.
  final DateTime today;
  DateTime get _today => today;

  /// Printed per working day needed from here on to still reach [monthTarget].
  int? get neededPerDay {
    final target = monthTarget;
    final left = workingDaysLeft;
    if (target == null || left == 0) return null;
    return max(0, ((target - printed) / left).ceil());
  }

  /// Working days that have passed, and how many of them reached their target.
  int get workingDaysSoFar => _working.where((d) => d.counted).length;
  int get daysOnTarget => _working.where((d) => d.counted && d.target != null && (d.printed ?? 0) >= d.target!).length;
  int get missingDays => days.where((d) => d.missing).length;

  /// Days whose machine total doesn't match the day before plus what was printed.
  int get totalWarnings => days.where((d) => (d.gap ?? 0) != 0).length;

  /// The counted day furthest below its target.
  MonthDay? get worstDay {
    MonthDay? worst;
    for (final d in days) {
      final diff = d.diff;
      if (diff != null && diff < 0 && (worst == null || diff < worst.diff!)) worst = d;
    }
    return worst;
  }

  /// The month is over.
  bool get isPast => DateTime(month.year, month.month + 1).isBefore(_today) || DateTime(month.year, month.month + 1) == _today;
}

extension<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
}
