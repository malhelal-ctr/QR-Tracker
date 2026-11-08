import 'package:flutter/material.dart';
import 'package:qr_tracker/core/data/models.dart';
import 'package:qr_tracker/core/data/product_stats.dart';
import 'package:qr_tracker/core/data/progress_stats.dart';
import 'package:qr_tracker/core/data/stock_stats.dart';
import 'package:qr_tracker/core/data/month_plan.dart';
import 'package:qr_tracker/core/utils/format.dart';
import 'package:qr_tracker/features/daily_log/model/daily_log_state.dart';
import 'package:qr_tracker/features/daily_log/widget/log_entry_panel.dart';
import 'package:qr_tracker/features/daily_log/widget/month_bar.dart';
import 'package:qr_tracker/features/daily_log/widget/month_calendar.dart';
import 'package:qr_tracker/features/daily_log/widget/month_header.dart';
import 'package:qr_tracker/features/daily_log/widget/month_table.dart';
import 'package:qr_tracker/features/dashboard/widget/empty_list_card.dart';
import 'package:qr_tracker/features/dashboard/widget/plan_card.dart';
import 'package:qr_tracker/features/dashboard/widget/position_card.dart';
import 'package:qr_tracker/features/dashboard/widget/stock_card.dart';
import 'package:qr_tracker/features/dashboard/widget/today_card.dart';
import 'package:qr_tracker/features/data/widget/archived_list_sheet.dart';
import 'package:qr_tracker/features/data/widget/danger_zone_card.dart';
import 'package:qr_tracker/features/data/widget/export_backup_card.dart';
import 'package:qr_tracker/features/data/widget/list_history_card.dart';
import 'package:qr_tracker/features/products/widget/product_row.dart';
import 'package:widgetbook/widgetbook.dart';

void _tap() {}

/// This month logged up to yesterday at around the daily target, with one missing day, Fridays off
/// and machine totals (one that doesn't match).
MonthSummary _month(BuildContext context) {
  final daily = context.knobs.int.input(label: 'Daily target', initialValue: 12000);
  final now = DateTime.now();
  final days = <String, Day>{};
  var total = 1300000;
  for (var i = 1; i < now.day; i++) {
    final date = DateTime(now.year, now.month, i);
    if (date.weekday == DateTime.friday || i == 3) continue;
    final printed = daily + (i * 937 % 3000) - 1500;
    total += printed + (i == 6 ? 800 : 0);
    days[ymd(date)] = Day(id: '$i', date: ymd(date), counter: printed, total: total, product: 'Cover Coat', note: i == 4 ? 'Maintenance 14:00' : '');
  }
  final before = ymd(DateTime(now.year, now.month, 0)); // last day of the month before: the starting total
  days[before] = Day(id: '0', date: before, total: 1300000);
  return MonthSummary.compute(
    month: now,
    days: days,
    dailyTarget: daily,
    isOff: (d) => DateTime.parse(d).weekday == DateTime.friday,
  );
}

/// Progress for a 50,000-code list, driven by knobs so each dashboard card can be pushed into its edge cases.
ProgressStats _progress(BuildContext context) {
  final total = context.knobs.int.input(label: 'Total codes', initialValue: 50000);
  final printed = context.knobs.int.input(label: 'Printed', initialValue: 32000).clamp(0, total);
  final scanned = context.knobs.boolean(label: 'Scanned yet', initialValue: true);
  final todayPrinted = context.knobs.intOrNull.input(label: 'Printed today', initialValue: 1450);
  final fromCounter = context.knobs.boolean(label: 'Today from counter');
  final now = DateTime.now().millisecondsSinceEpoch;
  final scan = scanned ? Scan(ts: now, code: 'QR-$printed', pos: printed) : null;
  return ProgressStats(
    total: total,
    printed: printed,
    remaining: total - printed,
    last: scan,
    highest: scan,
    todayPrinted: todayPrinted,
    todaySince: todayPrinted == null || fromCounter ? null : Scan(ts: now - 4 * 3600 * 1000, code: 'QR-1', pos: printed - todayPrinted),
    todayScans: fromCounter ? 0 : context.knobs.int.slider(label: 'Scans today', initialValue: 3, max: 10),
    target: context.knobs.intOrNull.input(label: 'Daily target', initialValue: 1800),
    daysLeft: context.knobs.intOrNull.input(label: 'Days left', initialValue: 12),
    suggested: context.knobs.intOrNull.input(label: 'Needed / day', initialValue: 1500),
    avg: context.knobs.intOrNull.input(label: 'Avg / day', initialValue: 1620),
    finish: DateTime.now().add(const Duration(days: 11)),
  );
}

StockStats _stock(BuildContext context) => StockStats(
      hasData: context.knobs.boolean(label: 'Has data', initialValue: true),
      onHand: context.knobs.int.input(label: 'On hand', initialValue: 21000),
      usedSinceCount: 4000,
      received: 10000,
      wasted: 120,
      daysOfCover: context.knobs.intOrNull.input(label: 'Days of cover', initialValue: 13),
      shortfall: context.knobs.int.input(label: 'Shortfall', initialValue: 0),
      lowStock: context.knobs.intOrNull.input(label: 'Low stock alert', initialValue: 5000),
    );

ArchivedList _archived(String fileName, [String product = 'Cover Coat']) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return ArchivedList(
    id: fileName,
    fileName: fileName,
    codeText: 'QR-1\nQR-2',
    total: 50000,
    printed: 49980,
    logged: 50120,
    archivedAt: now,
    importedAt: now - 30 * 24 * 3600 * 1000,
    scans: [Scan(ts: now, code: 'QR-49980', pos: 49980)],
    product: product,
  );
}

final featureUseCases = <WidgetbookNode>[
  WidgetbookFolder(name: 'Dashboard', children: [
    WidgetbookComponent(name: 'PositionCard', useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => PositionCard(
          stats: _progress(context),
          fileName: context.knobs.string(label: 'File name', initialValue: 'batch_2026_10.xlsx'),
          onScan: _tap,
        ),
      ),
    ]),
    WidgetbookComponent(name: 'TodayCard', useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => TodayCard(stats: _progress(context), goalMet: context.knobs.boolean(label: 'Goal met'), onLog: _tap),
      ),
    ]),
    WidgetbookComponent(name: 'PlanCard', useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => PlanCard(
          stats: _progress(context),
          onPace: context.knobs.booleanOrNull(label: 'On pace', initialValue: true),
        ),
      ),
    ]),
    WidgetbookComponent(name: 'StockCard', useCases: [
      WidgetbookUseCase(name: 'Default', builder: (context) => StockCard(stock: _stock(context), onOpen: _tap)),
    ]),
    WidgetbookComponent(name: 'EmptyListCard', useCases: [
      WidgetbookUseCase(name: 'Default', builder: (context) => const EmptyListCard(onImport: _tap)),
    ]),
  ]),
  WidgetbookFolder(name: 'Daily log', children: [
    WidgetbookComponent(name: 'MonthBar', useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => MonthBar(
          month: DateTime.now(),
          view: context.knobs.object.dropdown(label: 'View', options: LogView.values, labelBuilder: (v) => v.name),
          onPrevious: _tap,
          onNext: _tap,
          onPick: (_) {},
          onView: (_) {},
        ),
      ),
    ]),
    WidgetbookComponent(name: 'MonthHeader', useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => MonthHeader(summary: _month(context), ownTarget: context.knobs.boolean(label: 'Own target', initialValue: true), onEditTarget: _tap),
      ),
    ]),
    WidgetbookComponent(name: 'MonthCalendar', useCases: [
      WidgetbookUseCase(name: 'Default', builder: (context) => MonthCalendar(summary: _month(context), onTap: (_) {}, onToggleOff: (_, _) {})),
    ]),
    WidgetbookComponent(name: 'MonthTable', useCases: [
      WidgetbookUseCase(name: 'Default', builder: (context) => MonthTable(summary: _month(context), onTap: (_) {})),
    ]),
    WidgetbookComponent(name: 'LogEntryPanel', useCases: [
      WidgetbookUseCase(
        name: 'New log',
        builder: (context) => LogEntryPanel(
          entry: LogEntry(
            date: ymd(DateTime.now()),
            previousTotal: context.knobs.intOrNull.input(label: 'Previous total', initialValue: 1470500),
            previousTotalDate: ymd(DateTime.now().subtract(const Duration(days: 1))),
            monthTarget: 12000,
            product: 'Cover Coat',
          ),
          products: const ['Cover Coat'],
          onSave: (_) async {},
          onDelete: () async {},
          onDate: (_) {},
          onOffChanged: (_) {},
          onClose: _tap,
          onScan: _tap,
        ),
      ),
    ]),
  ]),
  WidgetbookFolder(name: 'Products', children: [
    WidgetbookComponent(name: 'ProductRow', useCases: [
      WidgetbookUseCase(
        name: 'In use',
        builder: (context) => const ProductRow(
          stats: ProductStats(name: 'Cover Coat', lists: 3, codes: 150000, days: 21, printed: 148200, active: true),
          onRename: _tap,
          onDelete: _tap,
        ),
      ),
      WidgetbookUseCase(
        name: 'Unused',
        builder: (context) => const ProductRow(stats: ProductStats(name: 'All Purpose Joint'), onRename: _tap, onDelete: _tap),
      ),
    ]),
  ]),
  WidgetbookFolder(name: 'Data', children: [
    WidgetbookComponent(name: 'ListHistoryCard', useCases: [
      WidgetbookUseCase(
        name: 'Grouped by product',
        builder: (context) => ListHistoryCard(
          lists: [_archived('Nov_1_2026_qr_serials.xlsx', 'All Purpose Joint'), _archived('Oct_31_2026_qr_serials.xlsx'), _archived('Oct_12_2026_qr_serials.xlsx'), _archived('Sep_2_2026_qr_serials.xlsx', '')],
          onOpen: (_) {},
        ),
      ),
      WidgetbookUseCase(name: 'Empty', builder: (context) => ListHistoryCard(lists: const [], onOpen: (_) {})),
    ]),
    WidgetbookComponent(name: 'ArchivedListSheet', useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => ArchivedListSheet(list: _archived('Oct_31_2026_qr_serials.xlsx'), onEditProduct: _tap, onExportCodes: _tap, onExportScans: _tap),
      ),
    ]),
    WidgetbookComponent(name: 'ExportBackupCard', useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => const ExportBackupCard(
          onExportLog: _tap,
          onExportScans: _tap,
          onExportStock: _tap,
          onBackup: _tap,
          onRestore: _tap,
        ),
      ),
    ]),
    WidgetbookComponent(name: 'DangerZoneCard', useCases: [
      WidgetbookUseCase(name: 'Default', builder: (context) => const DangerZoneCard(onErase: _tap)),
    ]),
  ]),
];
