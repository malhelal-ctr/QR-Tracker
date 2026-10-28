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
class ScanBaseline {
  const ScanBaseline({required this.pos, required this.source, this.at});

  /// 0 for [BaselineSource.listStart].
  final int pos;
  final BaselineSource source;

  /// The earlier log's production day, or the time of the earlier scan; null for the list start.
  final DateTime? at;
}

/// Baseline for logging [date] (yyyy-MM-dd) by scan: the position saved with the latest scan log
/// for an earlier day, else the highest code scanned before [date] began, else the start of the list.
ScanBaseline scanBaseline({required String date, required Iterable<Day> days, required Iterable<Scan> scans}) {
  final log = days.where((d) => d.scanPos != null && d.date.compareTo(date) < 0).fold<Day?>(null, (a, d) => a == null || d.date.compareTo(a.date) > 0 ? d : a);
  if (log != null) return ScanBaseline(pos: log.scanPos!, source: BaselineSource.log, at: DateTime.parse(log.date));

  final start = DateTime.parse(date).millisecondsSinceEpoch;
  final scan = scans.where((s) => s.pos != null && s.ts < start).fold<Scan?>(null, (a, s) => a == null || s.pos! > a.pos! ? s : a);
  if (scan != null) return ScanBaseline(pos: scan.pos!, source: BaselineSource.scan, at: DateTime.fromMillisecondsSinceEpoch(scan.ts));

  // positions are 1-based, so code #N means N codes printed from the start of the list
  return const ScanBaseline(pos: 0, source: BaselineSource.listStart);
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
