import 'dart:async';
import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../utils/format.dart';
import 'models.dart';
import 'printer_stats.dart';
import 'progress_stats.dart';
import 'scan_log.dart';
import 'shipping_stats.dart';
import 'stock_stats.dart';

/// Single source of truth for app data, persisted with Hive (files on Android, IndexedDB on web).
/// Cubits listen to [changes] and rebuild their state from it.
class TrackerRepository {
  late Box _kv;
  late Box _days;
  late Box _scans;
  late Box _stock;
  late Box _printer;
  final _changes = StreamController<void>.broadcast();

  List<String> _codes = [];
  String _fileName = '';
  int? _importedAt;
  String _periodEnd = '';
  int? _lowStock;
  int? _defaultTarget;
  int? _shipStartQty;
  String _shipStartDate = '';
  List<Scan> _scanList = [];

  /// Log records by id, and the same records merged into one per date.
  Map<String, Day> _entryMap = {};
  Map<String, Day> _dayMap = {};
  List<StockMove> _stockMoves = [];
  List<PrinterReading> _readings = [];
  Map<String, int> _index = {};

  Stream<void> get changes => _changes.stream;
  List<String> get codes => List.unmodifiable(_codes);
  String get fileName => _fileName;
  int? get importedAt => _importedAt;
  String get periodEnd => _periodEnd;
  int? get lowStock => _lowStock;

  /// Daily target used for every day that has no target of its own.
  int? get defaultTarget => _defaultTarget;

  /// The day's own target, else the default daily target.
  int? targetFor(Day? day) => day?.target ?? _defaultTarget;

  /// Printed lids already in store when shipment tracking started, and that date (yyyy-MM-dd).
  int? get shipStartQty => _shipStartQty;
  String get shipStartDate => _shipStartDate;

  ShippingStats get shipping => ShippingStats.compute(days: _dayMap.values, startQty: _shipStartQty, startDate: _shipStartDate);
  List<Scan> get scans => List.unmodifiable(_scanList);

  /// Log records by id; a date can have several. Lists and editing work on these.
  Map<String, Day> get entries => Map.unmodifiable(_entryMap);

  /// One merged [Day] per date (yyyy-MM-dd → day); totals, charts and targets work on these.
  Map<String, Day> get days => Map.unmodifiable(_dayMap);

  /// The record the forms write to for [date] (one per day for now), oldest first.
  Day? entryOn(String date) => _entryMap.values.where((d) => d.date == date).firstOrNull;

  /// Printer counter readings, each with what was printed since the previous one (oldest first).
  List<PrinterStep> get printerHistory => printerSteps(_readings);

  /// Oldest first.
  List<StockMove> get stockMoves => List.unmodifiable(_stockMoves);

  ProgressStats get progress => ProgressStats.compute(codes: _codes, scans: _scanList, days: _dayMap.values, periodEnd: _periodEnd, defaultTarget: _defaultTarget);

  StockStats get stock {
    final p = progress;
    // per record: each counter is checked against the stock count by its own log time
    return StockStats.compute(moves: _stockMoves, days: _entryMap.values, remainingCodes: p.remaining, avgDailyUse: p.avg, lowStock: _lowStock);
  }

  /// Scan of the highest code so far, i.e. how far the machine has got.
  Scan? get highestScan => _scanList.where((s) => s.pos != null).fold<Scan?>(null, (a, s) => a == null || s.pos! > a.pos! ? s : a);

  /// 1-based print position of [code] in the imported list, null when it is not in it.
  int? positionOf(String code) => _index[code.trim()];

  /// Where the machine stood when [date] (yyyy-MM-dd) began, for Log by scan.
  ScanBaseline scanBaselineFor(String date) => scanBaseline(date: date, days: _dayMap.values, scans: _scanList);

  /// Log by scan: the counter worked out from a scanned [code] for production day [date].
  /// What is already logged for that day (all its records) is passed along, so a scan can't silently lower it.
  ScanLogDraft scanLogDraft(String code, DateTime date) {
    final logged = _dayMap[ymd(date)];
    return ScanLogDraft(
      code: code.trim(),
      date: date,
      pos: positionOf(code),
      baseline: scanBaselineFor(ymd(date)),
      loggedCounter: logged?.counter,
      loggedPos: logged?.scanPos,
    );
  }

  /// Saves a confirmed scan log: the counter, and the scanned position for the next scan log to count from,
  /// in the day's record (one per day for now). The scan itself is recorded by the caller.
  Future<void> saveScanLog(ScanLogDraft draft, int counter) async {
    final key = ymd(draft.date);
    final existing = entryOn(key) ?? Day(date: key);
    await saveDay(existing.copyWith(counter: () => counter, scanPos: () => draft.savePos));
  }

  /// Code that follows [pos] in print order, if any.
  String? codeAfter(int pos) => pos < _codes.length ? _codes[pos] : null;

  /// [path]: a plain folder for the data instead of the app's storage (tests).
  Future<void> init({String? path}) async {
    if (path == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(path);
    }
    _kv = await Hive.openBox('kv');
    _days = await Hive.openBox('days');
    _scans = await Hive.openBox('scans');
    _stock = await Hive.openBox('stock');
    _printer = await Hive.openBox('printer');
    await _migrateDays();
    _load();
  }

  /// Unique, time-ordered record id (microseconds since epoch).
  String _newId() {
    var t = DateTime.now().microsecondsSinceEpoch;
    while (_entryMap.containsKey('$t') || _days.containsKey('$t')) {
      t++;
    }
    return '$t';
  }

  /// Older data is stored under the date (one record per day) without an id: re-store it under a new id.
  Future<void> _migrateDays() async {
    final all = {for (final k in _days.keys) k: Day.fromMap(_days.get(k) as Map)};
    final old = {for (final MapEntry(:key, :value) in all.entries) if (value.id.isEmpty) key: value};
    // oldest date first, so ids keep the dates' order
    for (final MapEntry(:key, value: day) in old.entries.toList()..sort((a, b) => a.value.date.compareTo(b.value.date))) {
      final id = _newId();
      await _days.put(id, day.copyWith(id: id).toMap());
      await _days.delete(key);
    }
  }

  void _setEntries(Iterable<Day> records) {
    // ids are time-ordered, so sorting by id keeps creation order for merging
    final sorted = records.toList()..sort((a, b) => a.id.compareTo(b.id));
    _entryMap = {for (final d in sorted) d.id: d};
    _dayMap = Day.mergeByDate(sorted);
  }

  void _load() {
    final c = _kv.get('codes') as Map?;
    _setCodes(c == null ? <String>[] : List<String>.from(c['list'] as List), c?['fileName'] as String? ?? '', c?['importedAt'] as int?);
    final settings = _kv.get('settings') as Map?;
    _periodEnd = settings?['periodEnd'] as String? ?? '';
    _lowStock = settings?['lowStock'] as int?;
    _defaultTarget = settings?['defaultTarget'] as int?;
    final shipStart = settings?['shipStart'] as Map?;
    _shipStartQty = shipStart?['qty'] as int?;
    _shipStartDate = shipStart?['date'] as String? ?? '';
    _setEntries(_days.values.map((v) => Day.fromMap(v as Map)));
    _scanList = _scans.values.map((v) => Scan.fromMap(v as Map)).toList()..sort((a, b) => a.ts.compareTo(b.ts));
    _stockMoves = _stock.values.map((v) => StockMove.fromMap(v as Map)).toList()..sort((a, b) => a.ts.compareTo(b.ts));
    _readings = _printer.values.map((v) => PrinterReading.fromMap(v as Map)).toList();
    _changes.add(null);
  }

  Map<String, dynamic> get _settings => {
        'periodEnd': _periodEnd,
        'lowStock': _lowStock,
        'defaultTarget': _defaultTarget,
        'shipStart': _shipStartQty == null ? null : {'qty': _shipStartQty, 'date': _shipStartDate},
      };

  Future<void> _saveSettings() => _kv.put('settings', _settings);

  void _setCodes(List<String> list, String name, int? at) {
    _codes = list;
    _fileName = name;
    _importedAt = at;
    _index = {};
    for (var i = 0; i < list.length; i++) {
      _index.putIfAbsent(list[i], () => i + 1);
    }
  }

  Future<void> importCodes(List<String> list, String name, {required bool clearScans}) async {
    final at = DateTime.now().millisecondsSinceEpoch;
    await _kv.put('codes', {'list': list, 'fileName': name, 'importedAt': at});
    if (clearScans) {
      await _scans.clear();
      _scanList = [];
    }
    _setCodes(list, name, at);
    _changes.add(null);
  }

  Future<Scan> addScan(String text) async {
    final code = text.trim();
    final scan = Scan(ts: DateTime.now().millisecondsSinceEpoch, code: code, pos: _index[code]);
    await _scans.add(scan.toMap());
    _scanList.add(scan);
    _changes.add(null);
    return scan;
  }

  /// Saves a log record under its id; a record without an id is new and gets one.
  Future<void> saveDay(Day day) async {
    if (day.id.isEmpty) day = day.copyWith(id: _newId());
    // stamp the time a counter is first logged; editing it later keeps the original time
    final previous = _entryMap[day.id];
    final counterAt = day.counter == null
        ? null
        : previous?.counter != null
            ? previous!.counterAt
            : DateTime.now().millisecondsSinceEpoch;
    day = day.copyWith(counterAt: () => counterAt);
    _setEntries({..._entryMap, day.id: day}.values);
    await _days.put(day.id, day.toMap());
    _changes.add(null);
  }

  Future<void> deleteDay(String id) async {
    _setEntries(_entryMap.values.where((d) => d.id != id));
    await _days.delete(id);
    _changes.add(null);
  }

  Future<void> setPeriodEnd(String value) async {
    _periodEnd = value;
    await _saveSettings();
    _changes.add(null);
  }

  /// Sets or clears the products shipped in a record (by default the day's record, or a new one);
  /// a record left with nothing logged is removed.
  Future<void> setShipped(String date, int? qty, {String? id}) async {
    final existing = id == null ? entryOn(date) : _entryMap[id];
    final day = (existing ?? Day(date: date)).copyWith(shipped: () => qty);
    if (!day.isEmpty) {
      await saveDay(day);
    } else if (day.id.isNotEmpty) {
      await deleteDay(day.id);
    }
  }

  /// Printed lids counted in store on [date]; null clears it (balance then starts at 0 from the first log).
  Future<void> setShipStart(int? qty, DateTime date) async {
    _shipStartQty = qty;
    _shipStartDate = qty == null ? '' : ymd(date);
    await _saveSettings();
    _changes.add(null);
  }

  Future<void> setDefaultTarget(int? value) async {
    _defaultTarget = value;
    await _saveSettings();
    _changes.add(null);
  }

  Future<void> setLowStock(int? value) async {
    _lowStock = value;
    await _saveSettings();
    _changes.add(null);
  }

  Future<void> addStockMove(StockMoveType type, int qty, DateTime date, {String note = ''}) async {
    final move = StockMove(ts: DateTime.now().millisecondsSinceEpoch, date: ymd(date), type: type, qty: qty, note: note);
    await _stock.put(move.ts.toString(), move.toMap());
    _stockMoves.add(move);
    _changes.add(null);
  }

  Future<void> deleteStockMove(int ts) async {
    await _stock.delete(ts.toString());
    _stockMoves.removeWhere((m) => m.ts == ts);
    _changes.add(null);
  }

  /// Adds a printer counter reading for production day [date], or replaces the one with the same id,
  /// then refills the Daily log counters it affects.
  Future<void> savePrinterReading({String? id, required DateTime date, required int value, bool reset = false, String note = ''}) async {
    final reading = PrinterReading(
      id: id ?? _newId(),
      ts: id == null ? DateTime.now().millisecondsSinceEpoch : _readings.firstWhere((p) => p.id == id).ts,
      date: ymd(date),
      value: value,
      reset: reset,
      note: note,
    );
    _readings = [..._readings.where((p) => p.id != reading.id), reading];
    await _printer.put(reading.id, reading.toMap());
    await _syncPrinterDays();
  }

  Future<void> deletePrinterReading(String id) async {
    _readings = _readings.where((p) => p.id != id).toList();
    await _printer.delete(id);
    await _syncPrinterDays();
  }

  /// Printer readings fill the Daily log: each production day with printed codes gets that amount as its
  /// counter (marked as from the printer). A day filled earlier that no longer has any is cleared.
  Future<void> _syncPrinterDays() async {
    final byDay = printedByDay(printerSteps(_readings));
    for (final MapEntry(key: date, value: printed) in byDay.entries) {
      final day = entryOn(date) ?? Day(date: date);
      if (day.counter != printed || !day.fromPrinter) await saveDay(day.copyWith(counter: () => printed, fromPrinter: true));
    }
    for (final day in _entryMap.values.where((d) => d.fromPrinter && !byDay.containsKey(d.date)).toList()) {
      final cleared = day.copyWith(counter: () => null, fromPrinter: false);
      cleared.isEmpty ? await deleteDay(day.id) : await saveDay(cleared);
    }
    _changes.add(null);
  }

  /// Same backup format as the web (Ionic) version, so backups move between them.
  String backupJson() => jsonEncode({
        'app': 'qr-tracker',
        'version': 1,
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
        'codes': {'list': _codes, 'fileName': _fileName, 'importedAt': _importedAt},
        'settings': _settings,
        'days': _entryMap.values.map((d) => d.toMap()).toList(),
        'scans': _scanList.map((s) => s.toMap()).toList(),
        'stock': _stockMoves.map((m) => m.toMap()).toList(),
        'printer': _readings.map((p) => p.toMap()).toList(),
      });

  Future<void> restore(String json) async {
    final data = jsonDecode(json);
    if (data is! Map || data['app'] != 'qr-tracker') throw const FormatException('This is not a QR Tracker backup file.');
    await Future.wait([_kv.clear(), _days.clear(), _scans.clear(), _stock.clear(), _printer.clear()]);
    final c = data['codes'] as Map? ?? {};
    await _kv.put('codes', {'list': List<String>.from(c['list'] as List? ?? []), 'fileName': c['fileName'] ?? '', 'importedAt': c['importedAt']});
    final settings = data['settings'] as Map?;
    await _kv.put('settings', {...?settings});
    // older backups (and the Ionic version) store days without ids; they are given one below
    for (final d in (data['days'] as List? ?? [])) {
      final day = Day.fromMap(d as Map);
      await _days.put(day.id.isEmpty ? 'date:${day.date}' : day.id, day.toMap());
    }
    await _migrateDays();
    await _scans.addAll((data['scans'] as List? ?? []).map((s) => Scan.fromMap(s as Map).toMap()));
    // backups from before stock tracking have no 'stock' key
    for (final m in (data['stock'] as List? ?? [])) {
      final move = StockMove.fromMap(m as Map);
      await _stock.put(move.ts.toString(), move.toMap());
    }
    // backups from before printer readings have no 'printer' key
    for (final p in (data['printer'] as List? ?? [])) {
      final reading = PrinterReading.fromMap(p as Map);
      await _printer.put(reading.id, reading.toMap());
    }
    _load();
  }

  Future<void> resetAll() async {
    await Future.wait([_kv.clear(), _days.clear(), _scans.clear(), _stock.clear(), _printer.clear()]);
    _load();
  }
}
