import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/month_plan.dart';
import '../../../core/data/models.dart';
import '../../../core/data/repository_listener.dart';
import '../../../core/data/scan_log.dart';
import '../../../core/data/tracker_repository.dart';
import '../../../core/utils/format.dart';
import '../model/daily_log_state.dart';

/// The Daily log by month: the month's days and totals, and the entry panel for one day.
class DailyLogCubit extends Cubit<DailyLogState> with RepositoryListener {
  DailyLogCubit(this._repository) : super(_build(_repository, DateTime.now())) {
    listenTo(_repository, () => emit(_build(_repository, state.month, from: state)));
  }

  final TrackerRepository _repository;

  static DailyLogState _build(TrackerRepository repository, DateTime month, {DailyLogState? from}) {
    final first = DateTime(month.year, month.month);
    final summary = repository.monthSummary(first);
    return DailyLogState(
      month: first,
      summary: summary,
      view: from?.view ?? LogView.calendar,
      ownTarget: repository.monthTargets.containsKey(ym(first)),
      products: repository.products,
      selected: from?.selected,
    );
  }

  void showMonth(DateTime month) => emit(_build(_repository, month, from: state));
  void previousMonth() => showMonth(DateTime(state.month.year, state.month.month - 1));
  void nextMonth() => showMonth(DateTime(state.month.year, state.month.month + 1));
  void setView(LogView view) => emit(state.copyWith(view: view));

  /// Opens the entry panel on [date] (yyyy-MM-dd), showing its month.
  void open(String date) {
    final d = DateTime.parse(date);
    final s = d.year == state.month.year && d.month == state.month.month ? state : _build(_repository, d, from: state);
    emit(s.copyWith(selected: () => date));
  }

  void closePanel() => emit(state.copyWith(selected: () => null));

  /// The day a new log is for: yesterday (the morning log of the day before).
  static String get defaultDate => ymd(DateTime.now().subtract(const Duration(days: 1)));

  /// What the entry panel shows for [date].
  LogEntry entryFor(String date) {
    final log = _repository.logOn(date);
    final prev = _repository.totalBefore(date);
    final prev2 = _repository.totalBefore(date, machine: LaserMachine.laser2);
    return LogEntry(
      date: date,
      log: log != null && log.hasLog ? log : null,
      previousTotal: prev?.total,
      previousTotalDate: prev?.date,
      previousTotal2: prev2?.total,
      previousTotalDate2: prev2?.date,
      monthTarget: _repository.dailyTargetFor(date.substring(0, 7)),
      off: _repository.isOff(date),
      holiday: _repository.holidayOn(date),
      product: log == null || log.product.isEmpty ? _repository.product : log.product,
    );
  }

  Future<void> saveLog({
    required String date,
    required int? counter,
    int? laser1,
    int? laser2,
    required int? total,
    int? total2,
    required bool totalReset,
    bool totalReset2 = false,
    required int? target,
    required String note,
    required String product,
  }) => _repository.saveLog(date: date, counter: counter, laser1: laser1, laser2: laser2, total: total, total2: total2, totalReset: totalReset, totalReset2: totalReset2, target: target, note: note, product: product);

  Future<void> deleteLog(String date) => _repository.deleteLog(date);

  Future<void> saveMachineReadings(String date, {required int? laser1, required bool reset1, required int? laser2, required bool reset2}) async {
    await _repository.saveMachineReadings(date: date, laser1: laser1, reset1: reset1, laser2: laser2, reset2: reset2);
  }

  /// Yesterday until both machine readings are present, then today.
  String get defaultReadingDate {
    final log = entryFor(defaultDate).log;
    return log?.total == null || log?.total2 == null ? defaultDate : ymd(DateTime.now());
  }

  Future<void> setDayOff(String date, bool off) => _repository.setDaysOff([date], off);

  /// Sets the shown month's daily target.
  Future<void> setMonthTarget(int? dailyTarget) => _repository.setMonthTarget(ym(state.month), dailyTarget);

  /// Log by scan: what the popup shows for a scanned code and production day.
  ScanLogDraft draftFromScan(String code, DateTime date, {LaserMachine machine = LaserMachine.laser1}) => _repository.scanLogDraft(code, date, machine: machine);

  /// Log by scan confirmed: records the scan and saves the counter.
  Future<void> saveScanLog(ScanLogDraft draft, int counter) async {
    await _repository.addScan(draft.code, machine: draft.machine);
    await _repository.saveScanLog(draft, counter);
  }
}
