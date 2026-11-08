import 'package:intl/intl.dart';

final _number = NumberFormat.decimalPattern();

String fmt(num? n) => n == null ? '—' : _number.format(n);

String fmtPct(int a, int b) => b == 0 ? '—' : '${(a / b * 100).toStringAsFixed(1)}%';

String fmtSigned(int n) => '${n >= 0 ? '+' : ''}${fmt(n)}';

String fmtDate(DateTime d) => DateFormat('EEE, MMM d').format(d);

String fmtDay(String ymd) => fmtDate(DateTime.parse(ymd));

String fmtTime(int ts) => DateFormat('MMM d, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts));

String fmtClock(int ts) => DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(ts));

/// Clock time for today, with the date for an earlier day (a scan shown again later).
String fmtStamp(int ts) => ymd(DateTime.fromMillisecondsSinceEpoch(ts)) == ymd(DateTime.now()) ? fmtClock(ts) : fmtTime(ts);

String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

final _compact = NumberFormat.compact();

/// Short number for tight spaces: 12.4K, 1.5M.
String fmtCompact(num? n) => n == null ? '—' : (n.abs() < 10000 ? _number.format(n) : _compact.format(n));

String fmtSignedCompact(int n) => '${n >= 0 ? '+' : '−'}${fmtCompact(n.abs())}';

String fmtMonth(DateTime d) => DateFormat('MMMM yyyy').format(d);
