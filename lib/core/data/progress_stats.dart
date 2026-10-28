import 'dart:math';

import '../utils/format.dart';
import 'models.dart';

/// Print progress derived from the QR list, scans, daily log and period end.
class ProgressStats {
  const ProgressStats({
    required this.total,
    required this.printed,
    required this.remaining,
    this.last,
    this.highest,
    this.todayPrinted,
    this.todaySince,
    this.todayScans = 0,
    this.target,
    this.daysLeft,
    this.suggested,
    this.avg,
    this.finish,
  });

  factory ProgressStats.compute({
    required List<String> codes,
    required List<Scan> scans,
    required Iterable<Day> days,
    required String periodEnd,
    int? defaultTarget,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final total = codes.length;
    final valid = scans.where((x) => x.pos != null).toList();
    final last = valid.lastOrNull;
    // the machine only moves forward, so the furthest code ever scanned is the print position;
    // a code scanned out of order later can't pull it back
    final highest = valid.isEmpty ? null : valid.reduce((a, b) => b.pos! > a.pos! ? b : a);
    final printed = highest?.pos ?? 0;
    final remaining = (total - printed).clamp(0, total);

    final startToday = DateTime(now.year, now.month, now.day);
    final t0 = startToday.millisecondsSinceEpoch;

    // Today's output: the counter logged for today when there is one, otherwise what today's
    // scans show (highest − lowest position scanned today, so a code scanned out of order
    // can't make it negative). Earlier days' scans are never used, so yesterday's printing
    // can't leak into today.
    final today = days.where((d) => d.date == ymd(now!)).firstOrNull;
    final todays = valid.where((x) => x.ts >= t0).toList();
    int? todayPrinted;
    Scan? since;
    var todayScans = todays.length;
    if (today?.counter case final counter?) {
      todayPrinted = counter;
      todayScans = 0;
    } else if (todays.isNotEmpty) {
      since = todays.first;
      final positions = todays.map((x) => x.pos!);
      todayPrinted = positions.reduce(max) - positions.reduce(min);
    }

    int? daysLeft;
    int? suggested;
    if (periodEnd.isNotEmpty) {
      daysLeft = DateTime.parse(periodEnd).difference(startToday).inDays + 1;
      if (daysLeft > 0) suggested = (remaining / daysLeft).ceil();
    }

    final logged = days.where((d) => d.counter != null).toList()..sort((a, b) => a.date.compareTo(b.date));
    final recent = logged.length > 7 ? logged.sublist(logged.length - 7) : logged;
    final avg = recent.isEmpty ? null : (recent.fold<int>(0, (a, d) => a + d.counter!) / recent.length).round();
    final finish = avg != null && avg > 0 && remaining > 0 ? startToday.add(Duration(days: (remaining / avg).ceil() - 1)) : null;

    return ProgressStats(
      total: total,
      printed: printed,
      remaining: remaining,
      last: last,
      highest: highest,
      todayPrinted: todayPrinted,
      todaySince: since,
      todayScans: todayScans,
      target: today?.target ?? defaultTarget,
      daysLeft: daysLeft,
      suggested: suggested,
      avg: avg,
      finish: finish,
    );
  }

  final int total;

  /// Position of the highest code scanned so far.
  final int printed;
  final int remaining;

  /// Most recent scan that matched the list.
  final Scan? last;

  /// Scan of the highest code so far; [printed] is its position.
  final Scan? highest;
  /// Printed today: today's logged counter, else highest − lowest position scanned today; null when neither exists.
  final int? todayPrinted;

  /// First scan of today, when [todayPrinted] comes from scans; null when it comes from the logged counter.
  final Scan? todaySince;

  /// Scans made today that [todayPrinted] is based on (0 when it comes from the logged counter).
  final int todayScans;

  bool get todayFromCounter => todayPrinted != null && todaySince == null;
  final int? target;
  final int? daysLeft;
  final int? suggested;
  final int? avg;
  final DateTime? finish;
}
