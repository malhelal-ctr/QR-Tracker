import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_tracker/core/data/models.dart';
import 'package:qr_tracker/core/data/product_stats.dart';
import 'package:qr_tracker/core/data/progress_stats.dart';
import 'package:qr_tracker/core/data/shipping_stats.dart';
import 'package:qr_tracker/core/data/printer_stats.dart';
import 'package:qr_tracker/core/data/scan_log.dart';
import 'package:qr_tracker/core/data/stock_stats.dart';
import 'package:qr_tracker/core/data/tracker_repository.dart';
import 'package:qr_tracker/core/utils/camera_probe.dart';
import 'package:qr_tracker/core/utils/file_io.dart';
import 'package:qr_tracker/core/utils/format.dart';
import 'package:qr_tracker/core/utils/period.dart';
import 'package:qr_tracker/features/dashboard/model/production_summary.dart';
import 'package:qr_tracker/core/data/lid_forecast.dart';
import 'package:qr_tracker/core/data/month_plan.dart';
import 'package:qr_tracker/core/notify/lid_notifier.dart';
import 'package:qr_tracker/features/data/model/import_preview.dart';
import 'package:qr_tracker/features/scan/cubit/scan_cubit.dart';
import 'package:qr_tracker/features/work_calendar/screen/work_calendar_screen.dart';
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
      final s = ProductionSummary.compute(days: days, targetFor: (d) => d.target ?? 8000, from: DateTime(2026, 10, 19), to: DateTime(2026, 10, 22));
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

  group('Lid forecast', () {
    // Fridays and Saturdays off
    bool weekend(String d) => DateTime.parse(d).weekday == DateTime.friday || DateTime.parse(d).weekday == DateTime.saturday;
    final wed = DateTime(2026, 11, 11, 10);

    test('workingDayAverage leaves out days off', () {
      final avg = workingDayAverage(
        days: const [Day(date: '2026-11-09', counter: 6000), Day(date: '2026-11-06', counter: 1000), Day(date: '2026-11-05', counter: 8000)],
        isOff: weekend,
        today: wed,
      );
      expect(avg, 7000); // the Friday's 1,000 isn't counted
    });

    test('20,000 lids at 6,000 a day from Wednesday: run out Monday, order by Thursday', () {
      final f = LidForecast.compute(onHand: 20000, average: 6000, isOff: weekend, leadTime: 2, bestRate: 12000, now: wed);
      expect(f.runOut, DateTime(2026, 11, 16)); // Wed, Thu, (Fri, Sat off), Sun covered
      expect((f.fullDaysLeft, f.orderBy, f.status), (3, DateTime(2026, 11, 12), LidStatus.ok));
      expect(f.daysLeft!.toStringAsFixed(2), '3.33');
      expect(f.bestRunOut, DateTime(2026, 11, 12)); // best case at the target
      expect(f.timeline.map((d) => d.left).take(6), [14000, 8000, 8000, 8000, 2000, 0]);
      expect(f.leftAtStartOf(DateTime(2026, 11, 15)), 8000);
    });

    test('status: low within the lead time, then critical, then out', () {
      LidStatus? status(int onHand) => LidForecast.compute(onHand: onHand, average: 6000, isOff: weekend, leadTime: 2, now: wed).status;
      expect(status(14000), LidStatus.low); // 2 full working days
      expect(status(6000), LidStatus.critical);
      expect(status(0), LidStatus.out);
      // today already logged: the forecast starts tomorrow
      final f = LidForecast.compute(onHand: 20000, average: 6000, isOff: weekend, leadTime: 2, todayLogged: true, now: wed);
      expect((f.start, f.runOut), (DateTime(2026, 11, 12), DateTime(2026, 11, 17)));
    });

    test('notifications: working days from the order-by day; straight away once low', () {
      StockStats stock(int onHand) => StockStats(hasData: true, onHand: onHand, usedSinceCount: 0, received: 0, wasted: 0)
          .withForecast(LidForecast.compute(onHand: onHand, average: 6000, isOff: weekend, leadTime: 2, now: wed));
      final ahead = plannedLidAlerts(stock: stock(20000), isOff: weekend, notifyAt: 8 * 60, now: wed, max: 3);
      expect(ahead.map((a) => a.at), [DateTime(2026, 11, 12, 8), DateTime(2026, 11, 15, 8), DateTime(2026, 11, 16, 8)]);
      expect(ahead.first.body, startsWith('14,000 lids left, runs out Mon, Nov 16'));

      // low already: the first one is today (its time has passed, so it is shown at once)
      final low = plannedLidAlerts(stock: stock(14000), isOff: weekend, notifyAt: 8 * 60, now: wed, max: 2);
      expect(low.first.at, DateTime(2026, 11, 11, 8));
      expect(plannedLidAlerts(stock: StockStats(hasData: false, onHand: 0, usedSinceCount: 0, received: 0, wasted: 0), isOff: weekend, notifyAt: 480, now: wed), isEmpty);
    });
  });

  test('monthDailyTarget: own month, else copied from the latest earlier month, else the fallback', () {
    const targets = {'2026-09': 9000, '2026-11': 12000};
    expect(monthDailyTarget('2026-09', targets), 9000);
    expect(monthDailyTarget('2026-10', targets), 9000);
    expect(monthDailyTarget('2027-01', targets), 12000);
    expect(monthDailyTarget('2026-08', targets, fallback: 7000), 7000);
  });

  test('totalGap: machine total against the previous total + printed', () {
    expect(totalGap(previousTotal: 1000, printed: 200, total: 1200), 0);
    expect(totalGap(previousTotal: 1000, printed: 200, total: 1250), 50);
    expect(totalGap(previousTotal: 1000, printed: 200, total: 300, reset: true), isNull);
    expect(totalGap(previousTotal: null, printed: 200, total: 1200), isNull);
  });

  test('MonthSummary: per-day miss, running month miss, plan from here and the machine check', () {
    final days = {
      for (final d in const [
        Day(date: '2026-09-30', total: 1000000), // starting machine total
        Day(date: '2026-10-01', counter: 11000, total: 1011000), // +1000, total matches
        // 10-02 is a day off
        Day(date: '2026-10-03', counter: 9000, target: 8000, total: 1021000), // own target: +1000; total 1000 too high
        // 10-04 not logged: a miss of the whole target
        Day(date: '2026-10-05', counter: 7000), // −3000, no total
      ])
        d.date: d,
    };
    final s = MonthSummary.compute(
      month: DateTime(2026, 10, 15),
      days: days,
      dailyTarget: 10000,
      isOff: (d) => d == '2026-10-02',
      now: DateTime(2026, 10, 6, 12), // today not logged yet: not counted
    );
    expect(s.days.length, 31);
    expect(s.days.map((d) => d.diff).take(6), [1000, null, 1000, -10000, -3000, null]);
    expect(s.days.map((d) => d.runningDiff).take(6), [1000, 1000, 2000, -8000, -11000, null]);
    expect(s.days.map((d) => d.gap).take(3), [0, null, 1000]);
    expect((s.workingDays, s.monthTarget, s.printed), (30, 29 * 10000 + 8000, 27000));
    expect((s.targetSoFar, s.missSoFar), (38000, -11000));
    expect((s.workingDaysLeft, s.neededPerDay), (26, 10424)); // (298,000 − 27,000) / 26 days
    expect((s.daysOnTarget, s.workingDaysSoFar, s.missingDays, s.totalWarnings), (2, 4, 1, 1));
    expect(s.worstDay!.key, '2026-10-04');
    expect((s.machinePrinted, s.machineLogged, s.unaccounted), (21000, 20000, 1000));
    expect(s.isPast, isFalse);
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

  test('scanBaseline adds the printed counts logged by hand since the last scan log', () {
    // Mon logged by scan at #50,000; Tue and Wed typed by hand; Thu scanned at #66,000
    const days = [
      Day(date: '2026-10-25', counter: 9000), // before the list was imported: not counted
      Day(date: '2026-10-26', counter: 5000, scanPos: 50000),
      Day(date: '2026-10-27', counter: 8000),
      Day(date: '2026-10-28', counter: 4000),
    ];
    final b = scanBaseline(date: '2026-10-29', days: days, scans: const [], listStart: '2026-10-20');
    expect((b.source, b.anchorPos, b.logged, b.loggedDays, b.pos), (BaselineSource.log, 50000, 12000, 2, 62000));
    expect(ScanLogDraft(code: 'x', date: DateTime(2026, 10, 29), pos: 66000, baseline: b).counter, 4000);

    // no scan at all: counts from the list start plus every day logged since the import
    final fromStart = scanBaseline(date: '2026-10-27', days: const [Day(date: '2026-10-25', counter: 9000), Day(date: '2026-10-26', counter: 5000)], scans: const [], listStart: '2026-10-26');
    expect((fromStart.source, fromStart.pos, fromStart.loggedDays), (BaselineSource.listStart, 5000, 1));

    // an ordinary scan: its own day is left out, later days are added
    int at(int day, int hour) => DateTime(2026, 10, day, hour).millisecondsSinceEpoch;
    final fromScan = scanBaseline(
      date: '2026-10-29',
      days: const [Day(date: '2026-10-27', counter: 7000), Day(date: '2026-10-28', counter: 6000)],
      scans: [Scan(ts: at(27, 10), code: 'a', pos: 30000)],
    );
    expect((fromScan.source, fromScan.anchorPos, fromScan.logged, fromScan.pos), (BaselineSource.scan, 30000, 6000, 36000));
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

  test('TrackerRepository: one log per day, printer readings become machine totals, monthly targets', () async {
    final dir = await Directory.systemTemp.createTemp('qr_tracker_month');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    // trial-phase data: two logs on one date (one with a shipment), printer readings, one daily target
    Hive.init(dir.path);
    final days = await Hive.openBox('days');
    await days.put('100', const Day(id: '100', date: '2026-10-23', counter: 3000, note: 'morning').toMap());
    await days.put('101', const Day(id: '101', date: '2026-10-23', counter: 4500, shipped: 2000, note: 'night').toMap());
    await days.put('102', const Day(id: '102', date: '2026-10-24', counter: 7000).toMap());
    final printer = await Hive.openBox('printer');
    for (final r in const [
      PrinterReading(id: '200', ts: 1, date: '2026-10-22', value: 1000000),
      PrinterReading(id: '201', ts: 2, date: '2026-10-23', value: 1005000),
      PrinterReading(id: '202', ts: 3, date: '2026-10-23', value: 1007500), // the day's last reading wins
    ]) {
      await printer.put(r.id, r.toMap());
    }
    await (await Hive.openBox('kv')).put('settings', {'defaultTarget': 8000});
    await Hive.close();

    final repo = TrackerRepository();
    await repo.init(path: dir.path);
    final log = repo.logOn('2026-10-23')!;
    expect((log.id, log.counter, log.note, log.total), ('100', 7500, 'morning · night', 1007500));
    final shipment = repo.entries['101']!;
    expect((shipment.counter, shipment.shipped, shipment.hasLog), (null, 2000, false)); // the shipment stays on its own
    expect(repo.days['2026-10-22']!.total, 1000000);

    // the old daily target is kept for the months logged so far; a later month's target doesn't change them
    expect(repo.dailyTargetFor('2026-10'), 8000);
    await repo.setMonthTarget('2026-11', 12000);
    expect((repo.dailyTargetFor('2026-10'), repo.dailyTargetFor('2026-12')), (8000, 12000));

    // saving a day updates its one log; the machine total is checked against the day before
    await repo.saveLog(date: '2026-10-24', counter: 7000, total: 1014500);
    expect(repo.entries.values.where((d) => d.date == '2026-10-24').length, 1);
    final oct = repo.monthSummary(DateTime(2026, 10), now: DateTime(2026, 10, 25));
    expect(oct.days[23].gap, 0);

    await repo.setDaysOff(['2026-10-25'], true);
    expect(repo.targetFor(const Day(date: '2026-10-25')), isNull);
    expect(repo.targetFor(const Day(date: '2026-10-26')), 8000);

    // deleting a log keeps a shipment on the same record
    await repo.deleteLog('2026-10-23');
    expect((repo.days['2026-10-23']!.counter, repo.days['2026-10-23']!.shipped), (null, 2000));

    // a backup keeps targets, days off and totals; printer readings aren't turned into totals again
    final backup = repo.backupJson();
    await repo.resetAll();
    await repo.restore(backup);
    expect((repo.dailyTargetFor('2026-11'), repo.isOff('2026-10-25'), repo.days['2026-10-24']!.total), (12000, true, 1014500));
    expect(repo.days['2026-10-23']!.total, isNull);
  });

  test('TrackerRepository: a machine reading never changes the daily printing log', () async {
    final dir = await Directory.systemTemp.createTemp('qr_tracker_reading');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    final repo = TrackerRepository();
    await repo.init(path: dir.path);
    await repo.saveLog(date: '2026-11-04', counter: 11500, total: null, note: 'kept');

    // a reading on a logged day keeps its printed count and note
    await repo.saveMachineReading(date: '2026-11-04', total: 1000000);
    final day = repo.days['2026-11-04']!;
    expect((day.counter, day.note, day.total, day.totalReset), (11500, 'kept', 1000000, false));

    // a reading on a day with no daily log adds only the reading: printing stays unlogged
    await repo.saveMachineReading(date: '2026-11-05', total: 1500, reset: true);
    final next = repo.days['2026-11-05']!;
    expect((next.counter, next.total, next.totalReset), (null, 1500, true));
    expect(repo.entries.values.where((d) => d.date == '2026-11-05').length, 1);

    // removing the reading removes a record that held nothing else, and keeps a daily log
    await repo.saveMachineReading(date: '2026-11-05', total: null);
    expect(repo.days['2026-11-05'], isNull);
    await repo.saveMachineReading(date: '2026-11-04', total: null);
    expect((repo.days['2026-11-04']!.counter, repo.days['2026-11-04']!.total), (11500, null));
  });

  test('TrackerRepository: weekend and holidays are days off; a single day can be switched', () async {
    final dir = await Directory.systemTemp.createTemp('qr_tracker_weekend');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    final repo = TrackerRepository();
    await repo.init(path: dir.path);
    await repo.setMonthTarget('2026-11', 10000);
    await repo.setWeekend({DateTime.friday});
    await repo.saveHoliday(DateTime(2026, 11, 17), DateTime(2026, 11, 18), 'National Day');

    expect((repo.isOff('2026-11-06'), repo.isOff('2026-11-05')), (true, false)); // a Friday, a Thursday
    expect((repo.isOff('2026-11-18'), repo.holidayOn('2026-11-18')), (true, 'National Day'));
    final nov = repo.monthSummary(DateTime(2026, 11), now: DateTime(2026, 11, 1));
    expect(nov.workingDays, 30 - 4 - 2); // 4 Fridays and 2 holiday days
    expect(nov.monthTarget, 24 * 10000);
    expect(nov.days[16].holiday, 'National Day');

    // working on a Friday; taking a Thursday off
    await repo.setDaysOff(['2026-11-06'], false);
    await repo.setDaysOff(['2026-11-05'], true);
    expect((repo.isOff('2026-11-06'), repo.isOff('2026-11-05'), repo.isOff('2026-11-13')), (false, true, true));

    final group = groupHolidays(repo.holidays).single;
    expect((group.name, group.from, group.to, group.dates.length), ('National Day', '2026-11-17', '2026-11-18', 2));
    await repo.deleteHolidays(['2026-11-17', '2026-11-18']);
    expect(repo.isOff('2026-11-18'), isFalse);

    // survives a backup
    await repo.saveHoliday(DateTime(2026, 12, 2), DateTime(2026, 12, 2), 'Founding');
    final backup = repo.backupJson();
    await repo.resetAll();
    expect(repo.weekend, isEmpty);
    await repo.restore(backup);
    expect(repo.weekend, {DateTime.friday});
    expect((repo.holidayOn('2026-12-02'), repo.isOff('2026-11-06')), ('Founding', false));
  });

  test('TrackerRepository: archiving moves the list and scans to history and keeps the daily log', () async {
    final dir = await Directory.systemTemp.createTemp('qr_tracker_archive');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    final repo = TrackerRepository();
    await repo.init(path: dir.path);
    final today = ymd(DateTime.now());
    await repo.importCodes(['A1', 'A2', 'A3'], 'batch-1.xlsx', clearScans: true);
    await repo.addScan('A3');
    await repo.addScan('stray');
    await repo.saveDay(Day(date: today, counter: 3, scanPos: 3, note: 'done'));
    await repo.saveDay(const Day(date: '2020-01-01', counter: 999)); // before the import: not this list's
    await repo.addStockMove(StockMoveType.count, 5000, DateTime.now());

    await repo.archiveList();

    expect(repo.codes, isEmpty);
    expect(repo.scans, isEmpty);
    expect((repo.fileName, repo.importedAt), ('', null));
    final list = repo.archivedLists.single;
    expect((list.fileName, list.total, list.printed, list.logged), ('batch-1.xlsx', 3, 3, 3));
    expect(list.codes, ['A1', 'A2', 'A3']);
    expect(list.scans.map((s) => (s.code, s.pos)), [('A3', 3), ('stray', null)]);

    // the log and stock stay; only the scan position, which belonged to the old list, is cleared
    final day = repo.days[today]!;
    expect((day.counter, day.note, day.scanPos), (3, 'done', null));
    expect(repo.days['2020-01-01']!.counter, 999);
    expect(repo.stockMoves.length, 1);

    // the next list's Log by scan counts from its own start
    await repo.importCodes(['B1', 'B2'], 'batch-2.xlsx', clearScans: true);
    expect(repo.scanBaselineFor(ymd(DateTime.now().add(const Duration(days: 1)))).source, BaselineSource.listStart);
    expect(repo.progress.printed, 0);
    await repo.archiveList();
    expect(repo.archivedLists.map((a) => a.fileName), ['batch-2.xlsx', 'batch-1.xlsx']);

    // kept across an app restart and in backups
    await Hive.close();
    final reopened = TrackerRepository();
    await reopened.init(path: dir.path);
    expect(reopened.archivedLists.last.scans.length, 2);
    final backup = reopened.backupJson();
    await reopened.resetAll();
    expect(reopened.archivedLists, isEmpty);
    await reopened.restore(backup);
    expect(reopened.archivedLists.map((a) => a.fileName), ['batch-2.xlsx', 'batch-1.xlsx']);
    expect(reopened.archivedLists.last.codes, ['A1', 'A2', 'A3']);

    // backups from before the list history still restore
    final old = jsonDecode(backup) as Map..remove('archive');
    await reopened.restore(jsonEncode(old));
    expect(reopened.archivedLists, isEmpty);
  });

  test('groupByProduct: same product together ignoring case, no product last', () {
    ArchivedList l(String id, String product) => ArchivedList(id: id, fileName: id, codeText: '', total: 10, printed: 0, logged: 0, archivedAt: 0, product: product);
    final groups = groupByProduct([l('nov', ''), l('oct2', 'Cover Coat'), l('oct1', 'All Purpose Joint'), l('sep', 'cover coat')]);
    expect(groups.map((g) => (g.$1, g.$2.map((a) => a.id).join(','))), [('Cover Coat', 'oct2,sep'), ('All Purpose Joint', 'oct1'), ('', 'nov')]);
  });

  test('TrackerRepository: a list keeps its product through archive, restart and backup', () async {
    final dir = await Directory.systemTemp.createTemp('qr_tracker_product');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    final repo = TrackerRepository();
    await repo.init(path: dir.path);
    await repo.importCodes(['A1'], 'Oct_31_2026_qr_serials.xlsx', clearScans: true, product: 'Cover Coat');
    expect(repo.product, 'Cover Coat');
    await repo.archiveList();
    expect(repo.product, '');
    expect(repo.archivedLists.single.product, 'Cover Coat');

    await repo.importCodes(['B1'], 'Nov_1_2026_qr_serials.xlsx', clearScans: true, product: 'Oops');
    await repo.setProduct(' All Purpose Joint ');
    expect(repo.products, ['All Purpose Joint', 'Cover Coat']);

    await Hive.close();
    final reopened = TrackerRepository();
    await reopened.init(path: dir.path);
    expect(reopened.product, 'All Purpose Joint');

    await reopened.setArchivedProduct(reopened.archivedLists.single.id, 'Cover Coat 5L');
    final backup = reopened.backupJson();
    await reopened.resetAll();
    await reopened.restore(backup);
    expect(reopened.product, 'All Purpose Joint');
    expect(reopened.archivedLists.single.product, 'Cover Coat 5L');
  });

  test('TrackerRepository: daily records take the active product, and products can be managed', () async {
    final dir = await Directory.systemTemp.createTemp('qr_tracker_products');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    final repo = TrackerRepository();
    await repo.init(path: dir.path);
    await repo.addProduct('Cover Coat');
    await repo.addProduct(' cover coat '); // same product
    await repo.addProduct('Spare');
    expect(repo.products, ['Cover Coat', 'Spare']);

    await repo.importCodes(['A1', 'A2'], 'Oct_31.xlsx', clearScans: true, product: 'Cover Coat');
    await repo.saveDay(const Day(date: '2026-10-31', counter: 5000)); // takes the active list's product
    await repo.saveDay(const Day(date: '2026-11-01', counter: 700, product: 'All Purpose Joint')); // chosen for the day
    await repo.saveDay(repo.entryOn('2026-10-31')!.copyWith(note: 'edited'));
    await repo.saveLog(date: '2026-11-02', counter: 300, total: 400); // the day's log takes the product too
    expect(repo.days['2026-10-31']!.product, 'Cover Coat');
    expect(repo.days['2026-11-01']!.product, 'All Purpose Joint');
    expect(repo.days['2026-11-02']!.product, 'Cover Coat');

    ProductStats stats(String name) => repo.productStats.firstWhere((p) => p.name == name);
    final cover = stats('Cover Coat');
    expect((cover.lists, cover.codes, cover.days, cover.printed, cover.active), (1, 2, 2, 5300, true));
    expect(stats('Spare').inUse, isFalse);

    // renaming reaches lists and days; renaming onto another product merges them
    await repo.renameProduct('All Purpose Joint', 'APJ');
    expect(repo.days['2026-11-01']!.product, 'APJ');
    await repo.archiveList();
    await repo.renameProduct('Cover Coat', 'apj');
    expect(repo.products, ['APJ', 'Spare']);
    expect(repo.archivedLists.single.product, 'APJ');
    expect(stats('APJ').printed, 6000);

    await repo.deleteProduct('Spare');
    await repo.deleteProduct('APJ'); // still used: stays
    expect(repo.products, ['APJ']);

    // saved products survive a backup, even unused ones
    await repo.addProduct('Unused');
    final backup = repo.backupJson();
    await repo.resetAll();
    expect(repo.products, isEmpty);
    await repo.restore(backup);
    expect(repo.products, ['APJ', 'Unused']);
  });

  test('TrackerRepository: codes match without dashes and are kept as written in the list', () async {
    final dir = await Directory.systemTemp.createTemp('qr_tracker_dashes');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    final repo = TrackerRepository();
    await repo.init(path: dir.path);
    await repo.importCodes(['LT-2026-000001', 'LT-2026-000002', 'LT2026000003'], 'list.xlsx', clearScans: true);

    expect(repo.positionOf('LT2026000002'), 2);
    expect(repo.positionOf(' LT-2026-000002 '), 2);
    expect(repo.positionOf('LT-2026-000003'), 3); // dashes typed where the list has none
    expect(repo.positionOf('LT2026000009'), isNull);
    expect(repo.positionOf('lt-2026-000001'), 1); // case is ignored too
    expect(repo.positionOf('Lt2026000003'), 3);
    expect(repo.positionOf('LT 2026 000001'), 1); // spaces inside the code too
    expect(repo.positionOf('lt - 2026 - 000002'), 2);

    final scan = await repo.addScan('lt2026000002');
    expect((scan.code, scan.pos), ('LT-2026-000002', 2));
    final stray = await repo.addScan(' XX-1 ');
    expect((stray.code, stray.pos), ('XX-1', null));
    expect(repo.scanLogDraft('LT2026000001', DateTime(2026, 11, 4)).code, 'LT-2026-000001');
  });

  test('ScanCubit opens on the last saved scan, and drops it when the scans are cleared', () async {
    final dir = await Directory.systemTemp.createTemp('qr_tracker_last_scan');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    final repo = TrackerRepository();
    await repo.init(path: dir.path);
    expect(ScanCubit(repo).state.result, isNull);

    await repo.importCodes(['A1', 'A2', 'A3', 'A4'], 'list.xlsx', clearScans: true, product: 'Cover Coat');
    await repo.addScan('A3');
    await repo.addScan('a1'); // out of order
    await repo.addScan('A2');

    final cubit = ScanCubit(repo);
    addTearDown(cubit.close);
    final r = cubit.state.result!;
    expect((r.scan.code, r.scan.pos, r.previous?.pos, r.nextCode, r.total, r.product), ('A2', 2, 3, 'A3', 4, 'Cover Coat'));
    expect(cubit.state.sessionCount, 0); // shown again, not a new scan

    await repo.archiveList();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.result, isNull);
  });

  test('ImportPreview keeps the product when other options change', () {
    final p = ImportPreview.parse('f.csv', ['A1', 'A2']).copyWith(product: 'Cover Coat');
    expect(p.copyWith(hasHeader: true).product, 'Cover Coat');
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
