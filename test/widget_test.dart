import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_tracker/core/data/models.dart';
import 'package:qr_tracker/core/data/progress_stats.dart';
import 'package:qr_tracker/core/data/shipping_stats.dart';
import 'package:qr_tracker/core/data/printer_stats.dart';
import 'package:qr_tracker/core/data/scan_log.dart';
import 'package:qr_tracker/core/data/stock_stats.dart';
import 'package:qr_tracker/core/data/tracker_repository.dart';
import 'package:qr_tracker/core/utils/camera_probe.dart';
import 'package:qr_tracker/core/utils/file_io.dart';
import 'package:qr_tracker/core/utils/period.dart';
import 'package:qr_tracker/features/dashboard/model/production_summary.dart';
import 'package:qr_tracker/features/daily_log/model/daily_log_state.dart';
import 'package:qr_tracker/features/data/model/import_preview.dart';
import 'package:qr_tracker/features/scan/model/camera_issue.dart';

void main() {
  test('parseCodes reads the first column and keeps leading zeros', () {
    final csv = 'QR Code\n"00123,x",foo\n00124;bar\n\n00125\n';
    final rows = parseCodes('codes.csv', Uint8List.fromList(utf8.encode('﻿$csv')));
    expect(rows, ['QR Code', '00123,x', '00124', '00125']);
    expect(looksLikeHeader(rows), isTrue);
  });

  test('toCsv quotes cells that need it', () {
    expect(toCsv([
      ['a', 'b,c', 'd"e']
    ]), '﻿a,"b,c","d""e"');
  });

  test('ImportPreview drops the header and counts duplicates', () {
    final p = ImportPreview.parse('f.csv', ['code', 'A1', 'A2', 'A1']);
    expect(p.hasHeader, isTrue);
    expect(p.codes, ['A1', 'A2', 'A1']);
    expect(p.duplicates, 1);
    expect(p.copyWith(hasHeader: false).codes.length, 4);
  });

  test('ProgressStats computes position, today and plan', () {
    final now = DateTime(2026, 10, 21, 12);
    final codes = List.generate(30000, (i) => 'C$i');
    final yesterday = DateTime(2026, 10, 20, 16).millisecondsSinceEpoch;
    final today = DateTime(2026, 10, 21, 9).millisecondsSinceEpoch;
    final s = ProgressStats.compute(
      codes: codes,
      scans: [Scan(ts: yesterday, code: 'x', pos: 7000), Scan(ts: today, code: 'y', pos: 12450)],
      days: const [Day(date: '2026-10-20', counter: 5200), Day(date: '2026-10-21', target: 6000)],
      periodEnd: '2026-10-30',
      now: now,
    );
    expect(s.printed, 12450);
    expect(s.remaining, 17550);
    expect(s.todayPrinted, 0); // one scan today: yesterday's scan is not used as the start
    expect(s.todayScans, 1);
    expect(s.target, 6000);
    expect(s.daysLeft, 10);
    expect(s.suggested, 1755);
    expect(s.avg, 5200);
    expect(s.finish, DateTime(2026, 10, 24));
  });

  test('ProgressStats: today = logged counter, else highest − lowest scan of today', () {
    final now = DateTime(2026, 10, 22, 13);
    int at(int day, int hour) => DateTime(2026, 10, day, hour).millisecondsSinceEpoch;
    final scans = [
      Scan(ts: at(21, 8), code: 'a', pos: 49802), // yesterday: ignored for today
      Scan(ts: at(22, 7), code: 'b', pos: 56495),
      Scan(ts: at(22, 12), code: 'c', pos: 58767),
    ];
    final fromScans = ProgressStats.compute(codes: const [], scans: scans, days: const [], periodEnd: '', now: now);
    expect(fromScans.todayPrinted, 58767 - 56495);
    expect(fromScans.todayFromCounter, isFalse);

    final fromCounter =
        ProgressStats.compute(codes: const [], scans: scans, days: const [Day(date: '2026-10-22', counter: 2272)], periodEnd: '', now: now);
    expect(fromCounter.todayPrinted, 2272);
    expect(fromCounter.todayFromCounter, isTrue);

    // a code scanned out of order (first scan further along than the latest) never gives a negative count
    final outOfOrder = ProgressStats.compute(
      codes: const [],
      scans: [Scan(ts: at(22, 6), code: 'd', pos: 67338), Scan(ts: at(22, 7), code: 'e', pos: 67301)],
      days: const [],
      periodEnd: '',
      now: now,
    );
    expect(outOfOrder.todayPrinted, 37);
    expect(outOfOrder.printed, 67338); // print position stays at the highest code scanned
    expect(outOfOrder.highest?.code, 'd');
    expect(outOfOrder.last?.code, 'e');
  });

  test('ProgressStats: today uses its own target, else the default daily target', () {
    final now = DateTime(2026, 10, 22, 12);
    ProgressStats stats(List<Day> days) =>
        ProgressStats.compute(codes: const [], scans: const [], days: days, periodEnd: '', defaultTarget: 8000, now: now);
    expect(stats(const []).target, 8000);
    expect(stats(const [Day(date: '2026-10-22', target: 6000)]).target, 6000);
    expect(stats(const [Day(date: '2026-10-21', target: 6000)]).target, 8000);
  });

  group('ProductionSummary', () {
    const days = [
      Day(date: '2026-10-18', counter: 8033),
      Day(date: '2026-10-19', counter: 6385),
      Day(date: '2026-10-20', counter: 4956, target: 5000), // own target
      Day(date: '2026-10-21', counter: 7568),
      Day(date: '2026-10-22', target: 8000), // no counter yet: not counted
    ];

    test('totals for a range, using each day\'s own target or the default', () {
      final s = ProductionSummary.compute(days: days, defaultTarget: 8000, from: DateTime(2026, 10, 19), to: DateTime(2026, 10, 22));
      expect(s.days.length, 3);
      expect(s.printed, 6385 + 4956 + 7568);
      expect(s.target, 8000 + 5000 + 8000);
      expect(s.difference, 18909 - 21000);
      expect(s.average, 6303);
      expect(s.goalMetDays, 0);
      expect(s.bestDay!.printed, 7568);
    });

    test('presets end today; weeks start on Monday', () {
      final now = DateTime(2026, 10, 22); // a Thursday
      expect(presetRange(PeriodPreset.last7Days, days: days, now: now), (DateTime(2026, 10, 16), DateTime(2026, 10, 22)));
      expect(presetRange(PeriodPreset.thisWeek, days: days, now: now), (DateTime(2026, 10, 19), DateTime(2026, 10, 22)));
      expect(presetRange(PeriodPreset.thisMonth, days: days, now: now), (DateTime(2026, 10, 1), DateTime(2026, 10, 22)));
      expect(presetRange(PeriodPreset.all, days: days, now: now), (DateTime(2026, 10, 18), DateTime(2026, 10, 22)));
    });
  });

  group('Shipping', () {
    const days = [
      Day(date: '2026-10-19', counter: 6385, shipped: 5000),
      Day(date: '2026-10-20', counter: 4956, shipped: 7000),
      Day(date: '2026-10-21', counter: 7568, shipped: 6000),
      Day(date: '2026-10-22', shipped: 2000), // shipped today, counter not logged yet
    ];

    test('store balance = start + printed − shipped from the start date', () {
      final s = ShippingStats.compute(days: days, startQty: 3000, startDate: '2026-10-20');
      expect(s.printed, 4956 + 7568);
      expect(s.shipped, 7000 + 6000 + 2000);
      expect(s.balance, 3000 + 12524 - 15000); // 524
      expect(s.avgShipped, 5000); // (5000+7000+6000+2000)/4
      expect(s.daysOfBuffer, 0);
    });

    test('without a start, everything counts from 0', () {
      final s = ShippingStats.compute(days: days);
      expect(s.balance, 18909 - 20000);
    });

    test('period: over / under', () {
      final p = ShippingPeriod.compute(days: days, from: DateTime(2026, 10, 19), to: DateTime(2026, 10, 21));
      expect(p.days.length, 3);
      expect(p.printed, 18909);
      expect(p.shipped, 18000);
      expect(p.difference, 909); // over: printed more than shipped
    });
  });

  group('StockStats', () {
    final now = DateTime(2026, 10, 22, 12);
    StockMove m(String date, StockMoveType type, int qty, int ts) => StockMove(ts: ts, date: date, type: type, qty: qty);

    test('count 20,000 on the 22nd, then log the 21st (7,000) → 13,000', () {
      final s = StockStats.compute(
        moves: [m('2026-10-22', StockMoveType.count, 20000, 100)],
        days: const [
          Day(date: '2026-10-20', counter: 4956, counterAt: 50), // logged before the count: already in it
          Day(date: '2026-10-21', counter: 7000, counterAt: 200), // logged after the count: subtracted
        ],
        remainingCodes: 0,
        now: now,
      );
      expect(s.onHand, 13000);
      expect(s.usedSinceCount, 7000);
    });

    test('entries apply in the order entered; a count resets the level', () {
      final s = StockStats.compute(
        moves: [
          m('2026-10-18', StockMoveType.received, 99999, 1), // before the count: ignored
          m('2026-10-19', StockMoveType.count, 20000, 2),
          m('2026-10-20', StockMoveType.received, 10000, 3),
          m('2026-10-21', StockMoveType.waste, 300, 4),
        ],
        days: const [
          Day(date: '2026-10-18', counter: 4000, counterAt: 1), // logged before the count: ignored
          Day(date: '2026-10-19', counter: 5000, counterAt: 5),
          Day(date: '2026-10-20', counter: 5200, counterAt: 6),
          Day(date: '2026-10-21', counter: 5000), // no log time (older data): falls back to its date
        ],
        remainingCodes: 30000,
        avgDailyUse: 5000,
        lowStock: 15000,
        now: now,
      );
      expect(s.onHand, 20000 + 10000 - 300 - 15200); // 14,500
      expect(s.usedSinceCount, 15200);
      expect(s.received, 10000);
      expect(s.wasted, 300);
      expect(s.daysOfCover, 2);
      expect(s.coverUntil, DateTime(2026, 10, 24));
      expect(s.shortfall, 30000 - 14500);
      expect(s.isLow, isTrue);
    });

    test('no stock entries yet → not tracked', () {
      final s = StockStats.compute(moves: const [], days: const [Day(date: '2026-10-21', counter: 7000, counterAt: 1)], remainingCodes: 0);
      expect(s.hasData, isFalse);
      expect(s.onHand, 0);
    });
  });

  test('DailyLogState: recent days, date filter and its totals', () {
    final history = [
      const Day(date: '2026-10-25', counter: 9000),
      const Day(date: '2026-10-24', counter: 7000, target: 6000),
      const Day(date: '2026-10-20', note: 'maintenance'),
      const Day(date: '2026-09-30', counter: 5000),
    ];
    final s = DailyLogState(
      date: DateTime(2026, 10, 25),
      history: history,
      defaultTarget: 8000,
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 25),
    );
    expect(s.filtered.map((d) => d.date), ['2026-10-25', '2026-10-24', '2026-10-20']);
    final sum = s.summary;
    expect(sum.printed, 16000);
    expect(sum.logged, 2); // the note-only day has no counter
    expect(sum.avg, 8000);
    expect((sum.met, sum.withTarget), (2, 2)); // 9000 ≥ 8000 default, 7000 ≥ 6000 own target
    expect(s.recent.length, 4);
  });

  test('Day.mergeByDate: records on one date add up, latest target wins, notes join', () {
    final merged = Day.mergeByDate(const [
      Day(id: '1', date: '2026-10-25', counter: 3000, counterAt: 20, target: 8000, note: 'morning'),
      Day(id: '2', date: '2026-10-25', counter: 4500, counterAt: 10, shipped: 2000, target: 9000),
      Day(id: '3', date: '2026-10-25', note: 'night shift'),
      Day(id: '4', date: '2026-10-24', counter: 7000),
    ]);
    final d = merged['2026-10-25']!;
    expect((d.id, d.counter, d.shipped, d.target, d.counterAt, d.note), ('1', 7500, 2000, 9000, 10, 'morning · night shift'));
    expect(merged['2026-10-24']!.counter, 7000);
  });

  test('DailyLogState summary counts several records on one date as one day', () {
    final s = DailyLogState(
      date: DateTime(2026, 10, 25),
      history: const [
        Day(id: '2', date: '2026-10-25', counter: 4500),
        Day(id: '1', date: '2026-10-25', counter: 3000),
      ],
      defaultTarget: 7000,
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 25),
    );
    final sum = s.summary;
    expect((sum.printed, sum.logged, sum.avg, sum.met, sum.withTarget), (7500, 1, 7500, 1, 1));
  });

  test('TrackerRepository moves date-keyed days to ids, then saves and deletes by id', () async {
    final dir = await Directory.systemTemp.createTemp('qr_tracker_test');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    // data as the previous version stored it: keyed by date, no id
    Hive.init(dir.path);
    final old = await Hive.openBox('days');
    await old.put('2026-10-24', const Day(date: '2026-10-24', counter: 7000, shipped: 500).toMap()..remove('id'));
    await old.put('2026-10-25', const Day(date: '2026-10-25', counter: 9000).toMap()..remove('id'));
    await Hive.close();

    final repo = TrackerRepository();
    await repo.init(path: dir.path);
    expect(repo.entries.length, 2);
    expect(repo.entries.keys.every((id) => id.isNotEmpty && !id.contains('-')), isTrue);
    expect(repo.days['2026-10-24']!.counter, 7000);
    expect(repo.entryOn('2026-10-25')!.counter, 9000);

    // a second record on the same date adds up in the per-date view
    await repo.saveDay(const Day(date: '2026-10-25', counter: 1000));
    expect(repo.entries.length, 3);
    expect(repo.days['2026-10-25']!.counter, 10000);

    await repo.deleteDay(repo.entryOn('2026-10-25')!.id);
    expect(repo.days['2026-10-25']!.counter, 1000);

    // backups without ids (older versions) are given ids on restore
    final backup = jsonDecode(repo.backupJson()) as Map;
    for (final d in backup['days'] as List) {
      (d as Map).remove('id');
    }
    await repo.restore(jsonEncode(backup));
    expect(repo.entries.length, 2);
    expect(repo.entries.values.every((d) => d.id.isNotEmpty), isTrue);
    expect(repo.days['2026-10-24']!.shipped, 500);
  });

  test('scanBaseline: last earlier scan log, else highest scan before the day, else list start; draft counter', () {
    int at(int day, int hour) => DateTime(2026, 10, day, hour).millisecondsSinceEpoch;
    final scans = [Scan(ts: at(23, 9), code: 'a', pos: 40000), Scan(ts: at(24, 15), code: 'b', pos: 52000), Scan(ts: at(25, 7), code: 'c', pos: 60000)];

    // no scan log yet: the highest code scanned before Oct 25 began
    final fromScan = scanBaseline(date: '2026-10-25', days: const [], scans: scans);
    expect((fromScan.pos, fromScan.source), (52000, BaselineSource.scan));

    // a scan log for an earlier day wins; one for the same day or later is ignored
    const days = [Day(date: '2026-10-23', scanPos: 45000), Day(date: '2026-10-24', scanPos: 50000), Day(date: '2026-10-25', scanPos: 58000)];
    final fromLog = scanBaseline(date: '2026-10-25', days: days, scans: scans);
    expect((fromLog.pos, fromLog.source, fromLog.at), (50000, BaselineSource.log, DateTime(2026, 10, 24)));

    // nothing before the day: counts from the start of the list
    final start = scanBaseline(date: '2026-10-23', days: const [], scans: scans);
    expect((start.pos, start.source, start.at), (0, BaselineSource.listStart, null));

    final date = DateTime(2026, 10, 25);
    expect(ScanLogDraft(code: 'x', date: date, pos: 58300, baseline: fromLog).counter, 8300);
    final behind = ScanLogDraft(code: 'x', date: date, pos: 49000, baseline: fromLog);
    expect((behind.counter, behind.behind), (null, true));
    // the first code in the list with nothing scanned before: 1 printed, not 0
    expect(ScanLogDraft(code: 'first', date: date, pos: 1, baseline: start).counter, 1);
    expect(ScanLogDraft(code: 'x', date: date, baseline: fromLog).inList, isFalse);

    // the day already has 20 logged by scan #20: scanning #15 keeps 20 and the saved position stays #20
    final back = ScanLogDraft(code: 'x', date: date, pos: 15, baseline: start, loggedCounter: 20, loggedPos: 20);
    expect((back.behindDay, back.counter, back.savePos, back.lowersLogged), (true, 20, 20, false));
    // scanning further ahead on the same day updates it
    final ahead = ScanLogDraft(code: 'x', date: date, pos: 26, baseline: start, loggedCounter: 20, loggedPos: 20);
    expect((ahead.behind, ahead.counter, ahead.savePos), (false, 26, 26));
    // 20 typed by hand (no scan position): a scan giving 15 is flagged as lowering it
    final hand = ScanLogDraft(code: 'x', date: date, pos: 15, baseline: start, loggedCounter: 20);
    expect((hand.behind, hand.counter, hand.lowersLogged), (false, 15, true));
  });

  test('printerSteps: printed = reading − previous; reset counts the whole reading; going down is flagged', () {
    PrinterReading r(String id, String date, int value, {bool reset = false}) => PrinterReading(id: id, ts: int.parse(id), date: date, value: value, reset: reset);
    final steps = printerSteps([
      r('3', '2026-10-24', 1012000), // entered out of order: sorted by production day
      r('1', '2026-10-22', 1000000),
      r('2', '2026-10-23', 1005000),
      r('4', '2026-10-25', 3000, reset: true), // counter reset, then 3,000 printed
      r('5', '2026-10-26', 2500), // lower without a reset
      r('6', '2026-10-26', 4000), // second reading the same day
    ]);
    expect(steps.map((s) => s.printed), [null, 5000, 7000, 3000, null, 1500]);
    expect(steps.map((s) => s.gap), [PrinterGap.first, null, null, null, PrinterGap.wentDown, null]);
    expect(printedByDay(steps), {'2026-10-23': 5000, '2026-10-24': 7000, '2026-10-25': 3000, '2026-10-26': 1500});
  });

  test('TrackerRepository: printer readings fill and clear the Daily log counter', () async {
    final dir = await Directory.systemTemp.createTemp('qr_tracker_printer');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    final repo = TrackerRepository();
    await repo.init(path: dir.path);
    await repo.saveDay(const Day(date: '2026-10-23', target: 6000, note: 'kept'));

    await repo.savePrinterReading(date: DateTime(2026, 10, 22), value: 1000000);
    expect(repo.days['2026-10-22'], isNull); // first reading: nothing to subtract yet
    await repo.savePrinterReading(date: DateTime(2026, 10, 23), value: 1006500);
    final day = repo.days['2026-10-23']!;
    expect((day.counter, day.fromPrinter, day.target, day.note), (6500, true, 6000, 'kept'));
    expect(repo.entries.length, 1); // filled into the existing record, not a new one

    // deleting the reading clears the counter it filled, keeping the rest of the day
    await repo.deletePrinterReading(repo.printerHistory.last.reading.id);
    final cleared = repo.days['2026-10-23']!;
    expect((cleared.counter, cleared.fromPrinter, cleared.target), (null, false, 6000));

    // backups carry the readings
    final backup = repo.backupJson();
    await repo.resetAll();
    expect(repo.printerHistory, isEmpty);
    await repo.restore(backup);
    expect(repo.printerHistory.single.reading.value, 1000000);
  });

  group('cameraIssues', () {
    List<String> titles(CameraEnv? env, [MobileScannerErrorCode? error]) => cameraIssues(env, error).map((i) => i.title).toList();

    test('all clear: Android app, or a browser with permission granted', () {
      expect(titles(const CameraEnv()), isEmpty);
      expect(titles(const CameraEnv(web: true, permission: CameraPermission.granted)), isEmpty);
    });

    test('http page: only the https issue, even though the camera also failed to start', () {
      expect(titles(const CameraEnv(web: true, secure: false, hasCameraApi: false), MobileScannerErrorCode.unsupported), ['Page is not opened over https']);
    });

    test('permission: blocked from the browser or the camera error; prompt offers Allow', () {
      final blocked = cameraIssues(const CameraEnv(web: true, permission: CameraPermission.denied), null).single;
      expect(blocked.blocking, isTrue);
      expect(blocked.canAllow, isTrue);
      expect(titles(const CameraEnv(), MobileScannerErrorCode.permissionDenied), ['Camera permission is blocked']);
      final prompt = cameraIssues(const CameraEnv(web: true, permission: CameraPermission.prompt), null).single;
      expect(prompt.blocking, isFalse);
      expect(prompt.canAllow, isTrue);
    });

    test('offline browser without a built-in reader needs internet for the first scan', () {
      expect(titles(const CameraEnv(web: true, nativeDetector: false, online: false, permission: CameraPermission.granted)), ['Internet needed for the first scan']);
      expect(titles(const CameraEnv(web: true, nativeDetector: true, online: false, permission: CameraPermission.granted)), isEmpty);
    });
  });
}
