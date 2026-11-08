import '../utils/format.dart';
import 'models.dart';

/// How urgent the lid stock is.
enum LidStatus {
  /// More working days of lids than the lead time.
  ok,

  /// Runs out within the lead time: order now.
  low,

  /// One working day or less left.
  critical,

  /// No lids left.
  out,
}

/// One day of the lid forecast.
class LidForecastDay {
  const LidForecastDay({required this.date, required this.off, required this.use, required this.left});

  final DateTime date;

  /// Day off (weekend, holiday, single day off): no printing.
  final bool off;

  /// Lids expected to be used that day.
  final int use;

  /// Lids left at the end of the day.
  final int left;
}

/// Average printed per working day: the last [count] working days with a printed count, before [today]
/// (today too once it is logged). Days off aren't counted, so a weekend doesn't pull the average down.
int? workingDayAverage({required Iterable<Day> days, required bool Function(String date) isOff, required DateTime today, int count = 7}) {
  final key = ymd(today);
  final logged = days.where((d) => d.counter != null && d.date.compareTo(key) <= 0 && !isOff(d.date)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final recent = logged.take(count).toList();
  if (recent.isEmpty) return null;
  return (recent.fold<int>(0, (a, d) => a + d.counter!) / recent.length).round();
}

/// When the lids run out: lids on hand are used up one working day at a time at the average daily
/// printing, skipping days off. The month target gives a best-case (earliest) run-out day only;
/// the status and reminders follow the average.
class LidForecast {
  const LidForecast({
    required this.onHand,
    required this.leadTime,
    required this.start,
    this.average,
    this.runOut,
    this.orderBy,
    this.fullDaysLeft,
    this.bestRate,
    this.bestRunOut,
    this.timeline = const [],
  });

  /// [onHand]: lids now. [average]: printed per working day. [bestRate]: the month's daily target.
  /// [leadTime]: working days needed to get new lids. [todayLogged]: today's printing is already in
  /// [onHand], so the forecast starts tomorrow.
  factory LidForecast.compute({
    required int onHand,
    required int? average,
    required bool Function(String date) isOff,
    required int leadTime,
    int? bestRate,
    bool todayLogged = false,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = todayLogged ? today.add(const Duration(days: 1)) : today;

    // working days from [start], at most a year ahead
    Iterable<DateTime> workingDays() sync* {
      for (var i = 0; i < 366; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        if (!isOff(ymd(d))) yield d;
      }
    }

    /// First working day [rate] can't be fully covered, and how many full working days come before it.
    (DateTime?, int) runOutAt(int? rate) {
      if (rate == null || rate <= 0) return (null, 0);
      var left = onHand;
      var full = 0;
      for (final d in workingDays()) {
        if (left < rate) return (d, full);
        left -= rate;
        full++;
      }
      return (null, full);
    }

    final (runOut, full) = runOutAt(average);
    final (bestRunOut, _) = runOutAt(bestRate);

    // the order-by day: [leadTime] working days before the run-out day, not before the start
    DateTime? orderBy;
    if (runOut != null) {
      final before = workingDays().takeWhile((d) => d.isBefore(runOut)).toList();
      orderBy = before.length > leadTime ? before[before.length - leadTime] : start;
    }

    // day-by-day lids until the run-out day (and one more working day), for the timeline
    final timeline = <LidForecastDay>[];
    if (average != null && average > 0) {
      var left = onHand;
      for (var i = 0; i < 120; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        final off = isOff(ymd(d));
        final use = off || left <= 0 ? 0 : (left < average ? left : average);
        left -= use;
        timeline.add(LidForecastDay(date: d, off: off, use: use, left: left));
        if (runOut != null && d.isAfter(runOut)) break;
        if (runOut == null && i >= 30) break;
      }
    }

    return LidForecast(
      onHand: onHand,
      leadTime: leadTime,
      start: start,
      average: average,
      runOut: runOut,
      orderBy: orderBy,
      fullDaysLeft: average == null || average <= 0 ? null : full,
      bestRate: bestRate,
      bestRunOut: bestRunOut,
      timeline: timeline,
    );
  }

  final int onHand;

  /// Printed per working day (recent average); null without printed counts.
  final int? average;

  /// Working days needed to get new lids after ordering.
  final int leadTime;

  /// First day the forecast counts: today, or tomorrow once today is logged.
  final DateTime start;

  /// First working day the lids can't cover a full day at the average; null without an average.
  final DateTime? runOut;

  /// Order new lids by this day to have them before [runOut].
  final DateTime? orderBy;

  /// Full working days the lids cover at the average.
  final int? fullDaysLeft;

  /// Best case: the month's daily target, and the run-out day at that rate.
  final int? bestRate;
  final DateTime? bestRunOut;

  /// Lids left day by day from [start] to just past [runOut].
  final List<LidForecastDay> timeline;

  /// Working days the lids last at the average, with the part day: 20,000 / 6,000 = 3.3.
  double? get daysLeft => average == null || average! <= 0 ? null : onHand / average!;

  LidStatus? get status {
    if (onHand <= 0) return LidStatus.out;
    final full = fullDaysLeft;
    if (full == null) return null;
    if (full <= 1) return LidStatus.critical;
    if (full <= leadTime) return LidStatus.low;
    return LidStatus.ok;
  }

  /// Stock needs ordering: low, critical or out.
  bool get needsOrder => status != null && status != LidStatus.ok;

  /// Lids expected to be left at the start of [date] (before its printing).
  int leftAtStartOf(DateTime date) {
    var left = onHand;
    for (final d in timeline) {
      if (!d.date.isBefore(date)) break;
      left = d.left;
    }
    return left;
  }
}
