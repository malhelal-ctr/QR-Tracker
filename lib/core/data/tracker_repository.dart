import 'dart:async';
import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../utils/format.dart';
import 'models.dart';
import 'lid_forecast.dart';
import 'month_plan.dart';
import 'product_stats.dart';
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
  late Box _archive;
  final _changes = StreamController<void>.broadcast();

  List<String> _codes = [];
  String _fileName = '';
  String _product = '';
  int? _importedAt;
  String _periodEnd = '';
  int? _lowStock;
  int _lidLeadTime = 2;
  bool _lidNotify = true;
  int _lidNotifyAt = 8 * 60;
  int? _defaultTarget;
  Map<String, int> _monthTargets = {};
  Set<String> _daysOff = {};
  Set<String> _workDays = {};
  Set<int> _weekend = {};
  Map<String, String> _holidays = {};
  bool _printerMigrated = false;
  int? _shipStartQty;
  String _shipStartDate = '';
  List<String> _productNames = [];
  List<Scan> _scanList = [];

  /// Log records by id, and the same records merged into one per date.
  Map<String, Day> _entryMap = {};
  Map<String, Day> _dayMap = {};
  List<StockMove> _stockMoves = [];
  List<PrinterReading> _readings = [];
  List<ArchivedList> _archived = [];
  Map<String, int> _index = {};

  Stream<void> get changes => _changes.stream;
  List<String> get codes => List.unmodifiable(_codes);
  String get fileName => _fileName;

  /// Product the active list's codes are printed for; empty when none was set.
  String get product => _product;
  int? get importedAt => _importedAt;
  String get periodEnd => _periodEnd;
  int? get lowStock => _lowStock;

  /// This month's daily target.
  int? get defaultTarget => dailyTargetFor(ym(DateTime.now()));

  /// Daily target of [month] ('yyyy-MM'), copied forward from the latest earlier month when it has none.
  int? dailyTargetFor(String month) => monthDailyTarget(month, _monthTargets, fallback: _defaultTarget);

  /// Months with a daily target of their own ('yyyy-MM' → codes per day).
  Map<String, int> get monthTargets => Map.unmodifiable(_monthTargets);

  /// [date] (yyyy-MM-dd) is marked as a day off: it has no target.
  bool isOff(String date) => !_workDays.contains(date) && (_daysOff.contains(date) || _offByCalendar(date));

  /// Off by the weekend or holiday settings (before any single-day exception).
  bool _offByCalendar(String date) => _holidays.containsKey(date) || _weekend.contains(DateTime.parse(date).weekday);

  /// Weekdays off every week (1 = Monday … 7 = Sunday).
  Set<int> get weekend => Set.unmodifiable(_weekend);

  /// Holidays: date (yyyy-MM-dd) → name.
  Map<String, String> get holidays => Map.unmodifiable(_holidays);

  /// Name of the holiday on [date], if it is one.
  String? holidayOn(String date) => _holidays[date];

  /// Single days marked off (long-press / panel), on top of the weekend and holidays; sorted.
  List<String> get singleDaysOff => _daysOff.toList()..sort();

  /// Weekend days or holidays marked as working days; sorted.
  List<String> get extraWorkDays => _workDays.toList()..sort();

  /// Removes a single-day exception: the day follows the weekend and holiday settings again.
  Future<void> clearDayException(String date) async {
    _daysOff = {..._daysOff}..remove(date);
    _workDays = {..._workDays}..remove(date);
    await _saveSettings();
    _changes.add(null);
  }

  /// The day's own target, else its month's daily target; null on a day off.
  int? targetFor(Day? day) => day == null ? defaultTarget : day.target ?? (isOff(day.date) ? null : dailyTargetFor(day.date.substring(0, 7)));

  /// The Daily log of [month]: every day with its target and result, and the month's totals.
  MonthSummary monthSummary(DateTime month, {DateTime? now}) =>
      MonthSummary.compute(month: month, days: _dayMap, dailyTarget: dailyTargetFor(ym(month)), isOff: isOff, holidayOn: holidayOn, now: now);

  /// The record holding the production log of [date] (one per day), else the day's first record.
  Day? logOn(String date) => _entryMap.values.where((d) => d.date == date && d.hasLog).firstOrNull ?? entryOn(date);

  /// The latest machine total logged before [date].
  ({String date, int total})? totalBefore(String date) => previousTotal(date, _dayMap.values);

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

  /// Oldest first.
  List<StockMove> get stockMoves => List.unmodifiable(_stockMoves);

  /// Lists moved to the list history, newest first.
  List<ArchivedList> get archivedLists => List.unmodifiable(_archived);

  /// Products added or used so far, one spelling each, to pick from so records of a product group together.
  List<String> get products {
    final names = <String, String>{};
    for (final p in [..._productNames, _product, ..._archived.map((a) => a.product), ..._entryMap.values.map((d) => d.product)]) {
      if (p.isNotEmpty) names.putIfAbsent(p.toLowerCase(), () => p);
    }
    return names.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<ProductStats> get productStats => [
        for (final name in products)
          ProductStats.compute(
            name: name,
            activeCodes: _product.toLowerCase() == name.toLowerCase() ? _codes.length : 0,
            archived: _archived,
            records: _entryMap.values,
          ),
      ];

  ProgressStats get progress => ProgressStats.compute(codes: _codes, scans: _scanList, days: _dayMap.values, periodEnd: _periodEnd, defaultTarget: targetFor(Day(date: ymd(DateTime.now()))));

  StockStats get stock {
    final p = progress;
    final now = DateTime.now();
    final average = workingDayAverage(days: _dayMap.values, isOff: isOff, today: now);
    // per record: each counter is checked against the stock count by its own log time
    final stats = StockStats.compute(moves: _stockMoves, days: _entryMap.values, remainingCodes: p.remaining, avgDailyUse: average, lowStock: _lowStock);
    if (!stats.hasData) return stats;
    final forecast = LidForecast.compute(
      onHand: stats.onHand,
      average: average,
      isOff: isOff,
      leadTime: _lidLeadTime,
      bestRate: dailyTargetFor(ym(now)),
      todayLogged: _dayMap[ymd(now)]?.counter != null,
      now: now,
    );
    return stats.withForecast(forecast);
  }

  /// Working days needed to get new lids after ordering.
  int get lidLeadTime => _lidLeadTime;

  /// Low-stock notification on, and its time of day (minutes after midnight).
  bool get lidNotify => _lidNotify;
  int get lidNotifyAt => _lidNotifyAt;

  /// Day (yyyy-MM-dd) a low-stock notification was last shown straight away, so it isn't repeated
  /// that day. Device-only: not in backups, and saving it doesn't notify [changes].
  String get lidNotifiedOn => _kv.get('lidNotifiedOn') as String? ?? '';
  Future<void> setLidNotifiedOn(String date) => _kv.put('lidNotifiedOn', date);

  /// Scan of the highest code so far, i.e. how far the machine has got.
  Scan? get highestScan => _scanList.where((s) => s.pos != null).fold<Scan?>(null, (a, s) => a == null || s.pos! > a.pos! ? s : a);

  /// 1-based print position of [code] in the imported list, null when it is not in it.
  int? positionOf(String code) => _index[_key(code)];

  /// Codes are matched without dashes or spaces and ignoring case, so `lt 2026012450` finds `LT-2026-012450`.
  static String _key(String code) => code.replaceAll(RegExp(r'[-\s]'), '').toUpperCase();

  /// [code] as written in the list when it is in it, else as typed.
  String _listCode(String code, int? pos) => pos == null ? code.trim() : _codes[pos - 1];

  /// Where the machine stood when [date] (yyyy-MM-dd) began, for Log by scan.
  ScanBaseline scanBaselineFor(String date) => scanBaseline(
        date: date,
        days: _dayMap.values,
        scans: _scanList,
        listStart: _importedAt == null ? null : ymd(DateTime.fromMillisecondsSinceEpoch(_importedAt!)),
      );

  /// Log by scan: the counter worked out from a scanned [code] for production day [date].
  /// What is already logged for that day (all its records) is passed along, so a scan can't silently lower it.
  ScanLogDraft scanLogDraft(String code, DateTime date) {
    final logged = _dayMap[ymd(date)];
    final pos = positionOf(code);
    return ScanLogDraft(
      code: _listCode(code, pos),
      date: date,
      pos: pos,
      baseline: scanBaselineFor(ymd(date)),
      loggedCounter: logged?.counter,
      loggedPos: logged?.scanPos,
    );
  }

  /// Saves a confirmed scan log: the counter, and the scanned position for the next scan log to count from,
  /// in the day's record (one per day for now). The scan itself is recorded by the caller.
  Future<void> saveScanLog(ScanLogDraft draft, int counter) async {
    final key = ymd(draft.date);
    final existing = logOn(key) ?? Day(date: key);
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
    _archive = await Hive.openBox('archive');
    await _migrateDays();
    _load();
    await _migrateLog();
  }

  /// Brings the Daily log up to one log per day with monthly targets:
  /// - dates with several production logs (from the trial phase) get them combined into the first one;
  ///   shipments stay in their own records;
  /// - each day's last printer reading (the old Printer tab) becomes that day's machine total, once;
  /// - the single daily target becomes the target of every month logged so far, so changing a month's
  ///   target later doesn't change the results of earlier months.
  Future<void> _migrateLog() async {
    final byDate = <String, List<Day>>{};
    for (final d in _entryMap.values.where((d) => d.hasLog)) {
      (byDate[d.date] ??= []).add(d);
    }
    for (final logs in byDate.values.where((l) => l.length > 1)) {
      final keep = logs.first;
      final merged = Day.mergeByDate(logs.map((d) => d.copyWith(shipped: () => null))).values.single;
      await _putRaw(keep.copyWith(
        counter: () => merged.counter,
        counterAt: () => merged.counterAt,
        target: () => merged.target,
        note: merged.note,
        scanPos: () => merged.scanPos,
        fromPrinter: merged.fromPrinter,
        product: merged.product,
        total: () => merged.total,
        totalReset: merged.totalReset,
      ));
      for (final other in logs.skip(1)) {
        final rest = _withoutLog(other);
        rest.isEmpty ? await _deleteRaw(rest.id) : await _putRaw(rest);
      }
    }

    if (!_printerMigrated) {
      final last = <String, PrinterReading>{};
      final reset = <String>{};
      for (final r in _readings.toList()..sort((a, b) => a.ts.compareTo(b.ts))) {
        last[r.date] = r;
        if (r.reset) reset.add(r.date);
      }
      for (final MapEntry(key: date, value: r) in last.entries) {
        final day = logOn(date) ?? Day(id: _newId(), date: date);
        if (day.total == null) await _putRaw(day.copyWith(total: () => r.value, totalReset: reset.contains(date)));
      }
      _printerMigrated = true;
      await _saveSettings();
    }

    if (_monthTargets.isEmpty && _defaultTarget != null) {
      final months = {ym(DateTime.now()), for (final d in _dayMap.values.where((d) => d.counter != null)) d.date.substring(0, 7)};
      _monthTargets = {for (final m in months) m: _defaultTarget!};
      await _saveSettings();
    }
    _changes.add(null);
  }

  /// The record with its production log taken out (a shipment stays).
  static Day _withoutLog(Day d) => d.copyWith(
        counter: () => null,
        counterAt: () => null,
        target: () => null,
        note: '',
        scanPos: () => null,
        fromPrinter: false,
        total: () => null,
        totalReset: false,
      );

  /// Stores a record as it is (no time or product stamping), for migrations.
  Future<void> _putRaw(Day day) async {
    _setEntries({..._entryMap, day.id: day}.values);
    await _days.put(day.id, day.toMap());
  }

  Future<void> _deleteRaw(String id) async {
    _setEntries(_entryMap.values.where((d) => d.id != id));
    await _days.delete(id);
  }

  /// Unique, time-ordered record id (microseconds since epoch); the clock can tick slower than that.
  String _newId() {
    var t = DateTime.now().microsecondsSinceEpoch;
    while (_entryMap.containsKey('$t') || _days.containsKey('$t') || _printer.containsKey('$t') || _archive.containsKey('$t')) {
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
    _setCodes(c == null ? <String>[] : List<String>.from(c['list'] as List), c?['fileName'] as String? ?? '', c?['importedAt'] as int?, product: c?['product'] as String? ?? '');
    final settings = _kv.get('settings') as Map?;
    _periodEnd = settings?['periodEnd'] as String? ?? '';
    _lowStock = settings?['lowStock'] as int?;
    _lidLeadTime = settings?['lidLeadTime'] as int? ?? 2;
    _lidNotify = settings?['lidNotify'] as bool? ?? true;
    _lidNotifyAt = settings?['lidNotifyAt'] as int? ?? 8 * 60;
    _defaultTarget = settings?['defaultTarget'] as int?;
    _monthTargets = {for (final MapEntry(:key, :value) in ((settings?['monthTargets'] as Map?) ?? {}).entries) key as String: value as int};
    _daysOff = {...List<String>.from(settings?['daysOff'] as List? ?? [])};
    _workDays = {...List<String>.from(settings?['workDays'] as List? ?? [])};
    _weekend = {...List<int>.from(settings?['weekend'] as List? ?? [])};
    _holidays = {for (final MapEntry(:key, :value) in ((settings?['holidays'] as Map?) ?? {}).entries) key as String: value as String};
    _printerMigrated = settings?['printerMigrated'] as bool? ?? false;
    final shipStart = settings?['shipStart'] as Map?;
    _shipStartQty = shipStart?['qty'] as int?;
    _shipStartDate = shipStart?['date'] as String? ?? '';
    _productNames = List<String>.from(settings?['products'] as List? ?? []);
    _setEntries(_days.values.map((v) => Day.fromMap(v as Map)));
    _scanList = _scans.values.map((v) => Scan.fromMap(v as Map)).toList()..sort((a, b) => a.ts.compareTo(b.ts));
    _stockMoves = _stock.values.map((v) => StockMove.fromMap(v as Map)).toList()..sort((a, b) => a.ts.compareTo(b.ts));
    _readings = _printer.values.map((v) => PrinterReading.fromMap(v as Map)).toList();
    _archived = _archive.values.map((v) => ArchivedList.fromMap(v as Map)).toList()..sort((a, b) => b.archivedAt.compareTo(a.archivedAt));
    _changes.add(null);
  }

  Map<String, dynamic> get _settings => {
        'periodEnd': _periodEnd,
        'lowStock': _lowStock,
        'lidLeadTime': _lidLeadTime,
        'lidNotify': _lidNotify,
        'lidNotifyAt': _lidNotifyAt,
        'defaultTarget': _defaultTarget,
        'monthTargets': _monthTargets,
        'daysOff': (_daysOff.toList()..sort()),
        'workDays': (_workDays.toList()..sort()),
        'weekend': (_weekend.toList()..sort()),
        'holidays': _holidays,
        'printerMigrated': _printerMigrated,
        'shipStart': _shipStartQty == null ? null : {'qty': _shipStartQty, 'date': _shipStartDate},
        'products': _productNames,
      };

  Future<void> _saveSettings() => _kv.put('settings', _settings);

  void _setCodes(List<String> list, String name, int? at, {String product = ''}) {
    _codes = list;
    _fileName = name;
    _importedAt = at;
    _product = product;
    _index = {};
    for (var i = 0; i < list.length; i++) {
      _index.putIfAbsent(_key(list[i]), () => i + 1);
    }
  }

  Future<void> importCodes(List<String> list, String name, {required bool clearScans, String product = ''}) async {
    final at = DateTime.now().millisecondsSinceEpoch;
    await _kv.put('codes', {'list': list, 'fileName': name, 'importedAt': at, 'product': product});
    if (clearScans) {
      await _scans.clear();
      _scanList = [];
    }
    _setCodes(list, name, at, product: product);
    _changes.add(null);
  }

  /// Sets the product of the active list.
  Future<void> setProduct(String value) async {
    _product = value.trim();
    await _kv.put('codes', {'list': _codes, 'fileName': _fileName, 'importedAt': _importedAt, 'product': _product});
    _changes.add(null);
  }

  /// Sets the product of an archived list, e.g. one archived before it had a product.
  Future<void> setArchivedProduct(String id, String value) async {
    _archived = [for (final a in _archived) a.id == id ? a.copyWith(product: value.trim()) : a];
    await _archive.put(id, _archived.firstWhere((a) => a.id == id).toMap());
    _changes.add(null);
  }

  /// Adds a product to pick from; a name already there (ignoring case) changes nothing.
  Future<void> addProduct(String value) async {
    final name = value.trim();
    if (name.isEmpty || products.any((p) => p.toLowerCase() == name.toLowerCase())) return;
    _productNames = [..._productNames, name];
    await _saveSettings();
    _changes.add(null);
  }

  /// Renames a product everywhere it is recorded. Renaming to another product's name merges them.
  Future<void> renameProduct(String old, String value) async {
    final name = products.where((p) => p.toLowerCase() == value.trim().toLowerCase() && p.toLowerCase() != old.toLowerCase()).firstOrNull ?? value.trim();
    if (name.isEmpty) return;
    bool same(String p) => p.toLowerCase() == old.toLowerCase();
    _productNames = [for (final p in _productNames) same(p) ? name : p];
    await _saveSettings();
    if (same(_product)) await setProduct(name);
    for (final list in _archived.where((a) => same(a.product)).toList()) {
      await setArchivedProduct(list.id, name);
    }
    for (final day in _entryMap.values.where((d) => same(d.product)).toList()) {
      await saveDay(day.copyWith(product: name));
    }
    _changes.add(null);
  }

  /// Removes a product no list or daily record uses; one still in use stays in [products].
  Future<void> deleteProduct(String name) async {
    _productNames = _productNames.where((p) => p.toLowerCase() != name.toLowerCase()).toList();
    await _saveSettings();
    _changes.add(null);
  }

  /// Moves the QR list and its scans to the list history, so the next list starts clean.
  /// Daily log records stay in the log: stock and shipping totals count them.
  Future<void> archiveList() async {
    final at = DateTime.now().millisecondsSinceEpoch;
    final from = _importedAt == null ? '' : ymd(DateTime.fromMillisecondsSinceEpoch(_importedAt!));
    final entry = ArchivedList(
      id: _newId(),
      fileName: _fileName,
      codeText: _codes.join('\n'),
      total: _codes.length,
      printed: progress.printed,
      logged: _dayMap.values.where((d) => d.date.compareTo(from) >= 0).fold(0, (a, d) => a + (d.counter ?? 0)),
      archivedAt: at,
      importedAt: _importedAt,
      scans: _scanList,
      product: _product,
    );
    // stored before anything is removed, so a failure part way can't lose the list
    await _archive.put(entry.id, entry.toMap());
    await _kv.delete('codes');
    await _scans.clear();
    _archived = [entry, ..._archived];
    _scanList = [];
    _setCodes([], '', null);
    // scan log positions belong to this list; the next list counts from its own start
    for (final day in _entryMap.values.where((d) => d.scanPos != null).toList()) {
      await saveDay(day.copyWith(scanPos: () => null));
    }
    _changes.add(null);
  }

  Future<Scan> addScan(String text) async {
    final pos = positionOf(text);
    final scan = Scan(ts: DateTime.now().millisecondsSinceEpoch, code: _listCode(text, pos), pos: pos);
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
    // a first counter with no product chosen (form, scan or printer) belongs to the active list's product
    final product = day.counter != null && previous?.counter == null && day.product.isEmpty ? _product : day.product;
    day = day.copyWith(counterAt: () => counterAt, product: product);
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

  /// Sets the daily target of [month] ('yyyy-MM'); null removes it (the month then copies the month before).
  Future<void> setMonthTarget(String month, int? value) async {
    _monthTargets = {..._monthTargets}..remove(month);
    if (value != null) _monthTargets[month] = value;
    await _saveSettings();
    _changes.add(null);
  }

  /// Marks [dates] (yyyy-MM-dd) as days off, or as working days. A weekend day or holiday marked as a
  /// working day is kept as an exception, so the weekend / holiday setting doesn't make it off again.
  Future<void> setDaysOff(Iterable<String> dates, bool off) async {
    final set = dates.toSet();
    if (off) {
      _daysOff = {..._daysOff, ...set};
      _workDays = _workDays.difference(set);
    } else {
      _daysOff = _daysOff.difference(set);
      _workDays = {..._workDays.difference(set), ...set.where(_offByCalendar)};
    }
    await _saveSettings();
    _changes.add(null);
  }

  /// Sets the weekend: weekdays that are off every week (1 = Monday … 7 = Sunday).
  Future<void> setWeekend(Set<int> weekdays) async {
    _weekend = {...weekdays};
    await _saveSettings();
    _changes.add(null);
  }

  /// Adds a holiday on every date from [from] to [to] (inclusive), or renames the dates already there.
  Future<void> saveHoliday(DateTime from, DateTime to, String name) async {
    final label = name.trim().isEmpty ? 'Holiday' : name.trim();
    final dates = [for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) ymd(d)];
    _holidays = {..._holidays, for (final d in dates) d: label};
    // a holiday is off even if the day was marked as a working day before
    _workDays = _workDays.difference(dates.toSet());
    await _saveSettings();
    _changes.add(null);
  }

  Future<void> deleteHolidays(Iterable<String> dates) async {
    _holidays = {..._holidays}..removeWhere((d, _) => dates.contains(d));
    await _saveSettings();
    _changes.add(null);
  }

  /// Saves the production log of [date]: one log per day, so an existing log is updated.
  /// [target] is the day's own target (null = the month's daily target). A shipment in the record is kept.
  Future<void> saveLog({
    required String date,
    required int? counter,
    required int? total,
    bool totalReset = false,
    int? target,
    String note = '',
    String product = '',
    int? scanPos,
  }) async {
    final existing = logOn(date) ?? Day(date: date);
    final day = existing.copyWith(
      counter: () => counter,
      total: () => total,
      totalReset: total != null && totalReset,
      target: () => target,
      note: note.trim(),
      product: product.trim(),
      scanPos: scanPos == null ? null : () => scanPos,
    );
    if (day.isEmpty) {
      if (day.id.isNotEmpty) await deleteDay(day.id);
    } else {
      await saveDay(day);
    }
  }

  /// Removes the production log of [date]; a shipment logged in the same record is kept.
  Future<void> deleteLog(String date) async {
    final day = logOn(date);
    if (day == null || day.id.isEmpty) return;
    final rest = _withoutLog(day);
    rest.isEmpty ? await deleteDay(day.id) : await saveDay(rest);
  }

  /// Saves the machine's total counter read on [date], and whether it was reset before the reading.
  /// Only the machine reading changes: the day's printed count, target and note stay as they are.
  /// A null [total] removes the reading.
  Future<void> saveMachineReading({required String date, required int? total, bool reset = false}) async {
    final existing = logOn(date);
    if (existing == null && total == null) return;
    final day = (existing ?? Day(date: date)).copyWith(total: () => total, totalReset: total != null && reset);
    if (day.isEmpty) {
      if (day.id.isNotEmpty) await deleteDay(day.id);
    } else {
      await saveDay(day);
    }
  }

  Future<void> setLowStock(int? value) async {
    _lowStock = value;
    await _saveSettings();
    _changes.add(null);
  }

  /// Working days needed to get new lids after ordering (at least 1).
  Future<void> setLidLeadTime(int days) async {
    _lidLeadTime = days < 1 ? 1 : days;
    await _saveSettings();
    _changes.add(null);
  }

  /// Low-stock notification: on or off, and the time of day (minutes after midnight).
  Future<void> setLidNotify({required bool on, int? minutes}) async {
    _lidNotify = on;
    if (minutes != null) _lidNotifyAt = minutes;
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

  /// Same backup format as the web (Ionic) version, so backups move between them.
  String backupJson() => jsonEncode({
        'app': 'qr-tracker',
        'version': 1,
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
        'codes': {'list': _codes, 'fileName': _fileName, 'importedAt': _importedAt, 'product': _product},
        'settings': _settings,
        'days': _entryMap.values.map((d) => d.toMap()).toList(),
        'scans': _scanList.map((s) => s.toMap()).toList(),
        'stock': _stockMoves.map((m) => m.toMap()).toList(),
        'printer': _readings.map((p) => p.toMap()).toList(),
        'archive': _archived.map((a) => a.toMap()).toList(),
      });

  Future<void> restore(String json) async {
    final data = jsonDecode(json);
    if (data is! Map || data['app'] != 'qr-tracker') throw const FormatException('This is not a QR Tracker backup file.');
    await Future.wait([_kv.clear(), _days.clear(), _scans.clear(), _stock.clear(), _printer.clear(), _archive.clear()]);
    final c = data['codes'] as Map? ?? {};
    await _kv.put('codes', {'list': List<String>.from(c['list'] as List? ?? []), 'fileName': c['fileName'] ?? '', 'importedAt': c['importedAt'], 'product': c['product'] ?? ''});
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
    // backups from before the list history have no 'archive' key
    for (final a in (data['archive'] as List? ?? [])) {
      final list = ArchivedList.fromMap(a as Map);
      await _archive.put(list.id, list.toMap());
    }
    _load();
    await _migrateLog();
  }

  Future<void> resetAll() async {
    await Future.wait([_kv.clear(), _days.clear(), _scans.clear(), _stock.clear(), _printer.clear(), _archive.clear()]);
    _load();
    await _migrateLog();
  }
}
