class Scan {
  const Scan({required this.ts, required this.code, this.pos});

  factory Scan.fromMap(Map m) => Scan(ts: m['ts'] as int, code: m['code'] as String, pos: m['pos'] as int?);

  final int ts;
  final String code;

  /// 1-based print position in the imported list, null when the code is not in it.
  final int? pos;

  Map<String, dynamic> toMap() => {'ts': ts, 'code': code, 'pos': pos};
}

enum StockMoveType {
  /// Lids delivered (+).
  received,

  /// Damaged / misprinted lids thrown away (−).
  waste,

  /// Physical count: sets the stock level.
  count,
}

/// One entry in the lid stock log.
class StockMove {
  const StockMove({required this.ts, required this.date, required this.type, required this.qty, this.note = ''});

  factory StockMove.fromMap(Map m) => StockMove(
        ts: m['ts'] as int,
        date: m['date'] as String,
        type: StockMoveType.values.byName(m['type'] as String),
        qty: m['qty'] as int,
        note: (m['note'] as String?) ?? '',
      );

  /// Creation time; also the storage key.
  final int ts;
  final String date; // yyyy-MM-dd
  final StockMoveType type;
  final int qty;
  final String note;

  Map<String, dynamic> toMap() => {'ts': ts, 'date': date, 'type': type.name, 'qty': qty, 'note': note};
}

/// One log record: what was printed / targeted / shipped on [date]. Stored under [id], so a date can
/// have several records; [Day.mergeByDate] adds them up into one per date for totals and charts.
class Day {
  const Day({this.id = '', required this.date, this.target, this.counter, this.counterAt, this.shipped, this.note = '', this.scanPos, this.fromPrinter = false});

  factory Day.fromMap(Map m) => Day(
        id: (m['id'] as String?) ?? '',
        date: m['date'] as String,
        target: m['target'] as int?,
        counter: m['counter'] as int?,
        counterAt: m['counterAt'] as int?,
        shipped: m['shipped'] as int?,
        note: (m['note'] as String?) ?? '',
        scanPos: m['scanPos'] as int?,
        fromPrinter: (m['fromPrinter'] as bool?) ?? false,
      );

  /// Storage key; empty until the record is first saved (and in older data, until it is migrated).
  final String id;
  final String date; // yyyy-MM-dd
  final int? target;
  final int? counter; // machine counter = codes printed

  /// When the counter was first logged (ms). Lid stock subtracts counters logged after a stock entry.
  final int? counterAt;

  /// Products shipped = printed lids taken out of the store.
  final int? shipped;
  final String note;

  /// Print position of the code scanned for this log (Log by scan); the next scan log counts from here.
  final int? scanPos;

  /// [counter] is filled from printer counter readings (Printer tab), and is kept in step with them.
  final bool fromPrinter;

  /// True when nothing is logged in the record.
  bool get isEmpty => target == null && counter == null && shipped == null && note.isEmpty;

  Day copyWith({String? id, int? Function()? target, int? Function()? counter, int? Function()? counterAt, int? Function()? shipped, String? note, int? Function()? scanPos, bool? fromPrinter}) => Day(
        id: id ?? this.id,
        date: date,
        target: target == null ? this.target : target(),
        counter: counter == null ? this.counter : counter(),
        counterAt: counterAt == null ? this.counterAt : counterAt(),
        shipped: shipped == null ? this.shipped : shipped(),
        note: note ?? this.note,
        scanPos: scanPos == null ? this.scanPos : scanPos(),
        fromPrinter: fromPrinter ?? this.fromPrinter,
      );

  Map<String, dynamic> toMap() => {'id': id, 'date': date, 'target': target, 'counter': counter, 'counterAt': counterAt, 'shipped': shipped, 'note': note, 'scanPos': scanPos, 'fromPrinter': fromPrinter};

  /// One [Day] per date from records in creation order: counters and shipments add up, the latest target wins,
  /// notes are joined, [counterAt] is the earliest and [scanPos] the furthest. The merged day keeps the first record's id.
  static Map<String, Day> mergeByDate(Iterable<Day> records) {
    int? sum(int? a, int? b) => a == null ? b : (b == null ? a : a + b);
    final merged = <String, Day>{};
    for (final r in records) {
      final m = merged[r.date];
      merged[r.date] = m == null
          ? r
          : m.copyWith(
              counter: () => sum(m.counter, r.counter),
              shipped: () => sum(m.shipped, r.shipped),
              target: () => r.target ?? m.target,
              counterAt: () => [m.counterAt, r.counterAt].nonNulls.fold<int?>(null, (a, t) => a == null || t < a ? t : a),
              note: [m.note, r.note].where((n) => n.isNotEmpty).join(' · '),
              scanPos: () => [m.scanPos, r.scanPos].nonNulls.fold<int?>(null, (a, p) => a == null || p > a ? p : a),
              fromPrinter: m.fromPrinter || r.fromPrinter,
            );
    }
    return merged;
  }
}

/// One reading of a printer's own QR counter. The counter keeps counting up, so what was printed
/// between two readings is the difference; [reset] marks a reading taken after the counter was reset.
class PrinterReading {
  const PrinterReading({
    required this.id,
    required this.ts,
    required this.date,
    required this.value,
    this.printer = defaultPrinter,
    this.reset = false,
    this.note = '',
  });

  factory PrinterReading.fromMap(Map m) => PrinterReading(
        id: m['id'] as String,
        ts: m['ts'] as int,
        date: m['date'] as String,
        value: m['value'] as int,
        printer: (m['printer'] as String?) ?? defaultPrinter,
        reset: (m['reset'] as bool?) ?? false,
        note: (m['note'] as String?) ?? '',
      );

  /// Until more printers can be added, every reading belongs to this one.
  static const defaultPrinter = 'Printer 1';

  /// Storage key.
  final String id;

  /// When the reading was entered (ms).
  final int ts;

  /// Production day (yyyy-MM-dd) that the printing since the previous reading belongs to.
  final String date;

  /// The counter shown on the printer.
  final int value;
  final String printer;

  /// The counter was reset before this reading, so everything on it was printed since the reset.
  final bool reset;
  final String note;

  Map<String, dynamic> toMap() => {'id': id, 'ts': ts, 'date': date, 'value': value, 'printer': printer, 'reset': reset, 'note': note};
}
