import 'package:intl/intl.dart';

final _number = NumberFormat.decimalPattern();

String fmt(num? n) => n == null ? '—' : _number.format(n);

String fmtPct(int a, int b) => b == 0 ? '—' : '${(a / b * 100).toStringAsFixed(1)}%';

String fmtSigned(int n) => '${n >= 0 ? '+' : ''}${fmt(n)}';

String fmtDate(DateTime d) => DateFormat('EEE, MMM d').format(d);

String fmtDay(String ymd) => fmtDate(DateTime.parse(ymd));

String fmtTime(int ts) => DateFormat('MMM d, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts));

String fmtClock(int ts) => DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(ts));

String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
