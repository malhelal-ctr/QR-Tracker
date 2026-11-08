import '../utils/format.dart';
import 'models.dart';

/// Where a scan log's starting point comes from.
enum BaselineSource {
  /// An earlier Log by scan.
  log,

  /// An ordinary scan made before the production day.
  scan,

  /// Nothing earlier: the start of the list (nothing printed yet).
  listStart,
}

/// Where the machine stood when a production day began; a scan log's counter is measured from it.
/// It is the last known position ([anchorPos]: a scan log, a scan, or the list start) plus the printed
/// counts logged by hand for the days after it ([logged]), so a day typed in between isn't counted twice.
class ScanBaseline {
  const ScanBaseline({required this.anchorPos, required this.source, this.at, this.logged = 0, this.loggedDays = 0});

  /// Position of the last scan log / scan; 0 for [BaselineSource.listStart].
  final int anchorPos;
  final BaselineSource source;

  /// The earlier log's production day, or the time of the earlier scan; null for the list start.
  final DateTime? at;

  /// Printed counts logged for the days between the anchor and the production day, and how many days.
  final int logged;
  final int loggedDays;

  /// Where the machine stood when the production day began.
  int get pos => anchorPos + logged;
}

/// Baseline for logging [date] (yyyy-MM-dd) by scan: the position saved with the latest scan log
/// for an earlier day, else the highest code scanned before [date] began, else the start of the list;
/// plus the printed counts logged for the days after that and before [date]. [listStart] (yyyy-MM-dd,
/// the list's import day) leaves out days logged before the list was in use.
ScanBaseline scanBaseline({required String date, required Iterable<Day> days, required Iterable<Scan> scans, String? listStart}) {
  ({int sum, int count}) loggedAfter(String? after) {
    var sum = 0, count = 0;
    for (final d in days) {
      if (d.counter == null || d.date.compareTo(date) >= 0) continue;
      if (after != null && d.date.compareTo(after) <= 0) continue;
      if (listStart != null && d.date.compareTo(listStart) < 0) continue;
      sum += d.counter!;
      count++;
    }
    return (sum: sum, count: count);
  }

  final log = days.where((d) => d.scanPos != null && d.date.compareTo(date) < 0).fold<Day?>(null, (a, d) => a == null || d.date.compareTo(a.date) > 0 ? d : a);
  if (log != null) {
    final since = loggedAfter(log.date);
    return ScanBaseline(anchorPos: log.scanPos!, source: BaselineSource.log, at: DateTime.parse(log.date), logged: since.sum, loggedDays: since.count);
  }

  final start = DateTime.parse(date).millisecondsSinceEpoch;
  final scan = scans.where((s) => s.pos != null && s.ts < start).fold<Scan?>(null, (a, s) => a == null || s.pos! > a.pos! ? s : a);
  if (scan != null) {
    final at = DateTime.fromMillisecondsSinceEpoch(scan.ts);
    // the scan's own day is left out: how much of it was printed after the scan isn't known
    final since = loggedAfter(ymd(at));
    return ScanBaseline(anchorPos: scan.pos!, source: BaselineSource.scan, at: at, logged: since.sum, loggedDays: since.count);
  }

  // positions are 1-based, so code #N means N codes printed from the start of the list
  final since = loggedAfter(null);
  return ScanBaseline(anchorPos: 0, source: BaselineSource.listStart, logged: since.sum, loggedDays: since.count);
}

/// A code scanned for Log by scan, before the counter is confirmed.
class ScanLogDraft {
  const ScanLogDraft({required this.code, required this.date, required this.baseline, this.pos, this.loggedCounter, this.loggedPos});

  final String code;

  /// Production day the log is for.
  final DateTime date;

  /// Print position of [code]; null when it is not in the imported list.
  final int? pos;

  /// Where the machine stood when [date] began.
  final ScanBaseline baseline;

  /// Counter already logged for [date], and the position of its last scan log (null when logged by hand).
  final int? loggedCounter;
  final int? loggedPos;

  bool get inList => pos != null;

  /// The scanned code is behind the last scan for this day (an earlier code than one already logged).
  bool get behindDay => pos != null && loggedPos != null && pos! < loggedPos!;

  /// The scanned code is behind where the day began (out of order, or an earlier code).
  bool get behindStart => pos != null && pos! < baseline.pos;

  bool get behind => behindDay || behindStart;

  /// Counter to show: codes printed since [baseline]. A code behind the day's last scan keeps what is
  /// already logged; one behind the day's start gives nothing. Null when the code is not in the list.
  int? get counter {
    if (pos == null) return null;
    if (behindDay) return loggedCounter;
    if (behindStart) return null;
    return pos! - baseline.pos;
  }

  /// [counter] would lower what is already logged for the day (e.g. a hand-typed counter was higher).
  bool get lowersLogged => !behind && counter != null && loggedCounter != null && counter! < loggedCounter!;

  /// Position to save: never moves back from the day's last scan.
  int? get savePos => behindDay ? loggedPos : pos;
}
