import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/models.dart';
import '../../../core/data/repository_listener.dart';
import '../../../core/data/scan_log.dart';
import '../../../core/data/tracker_repository.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/period.dart';
import '../model/daily_log_state.dart';

class DailyLogCubit extends Cubit<DailyLogState> with RepositoryListener {
  DailyLogCubit(this._repository) : super(_initial(_repository)) {
    listenTo(
      _repository,
      () => emit(
        _withPeriod(
          state.copyWith(
            history: _history(_repository),
            printer: _repository.printerHistory,
            suggested: () => _repository.progress.suggested,
            defaultTarget: () => _repository.defaultTarget,
          ),
        ),
      ),
    );
  }

  final TrackerRepository _repository;

  /// The picked range while the History filter is [PeriodPreset.custom].
  (DateTime, DateTime)? _custom;

  /// Sets the History filter range for [preset] (default: the current one); presets move with the data and today.
  DailyLogState _withPeriod(DailyLogState s, {PeriodPreset? preset}) {
    final p = preset ?? s.preset;
    final (from, to) = p == PeriodPreset.custom && _custom != null ? _custom! : presetRange(p, days: _repository.days.values);
    return s.copyWith(preset: p, from: from, to: to);
  }

  /// Morning entry: yesterday's counter, with the default daily target.
  static DailyLogState _initial(TrackerRepository repository, {int formVersion = 0}) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final day = repository.entryOn(ymd(yesterday));
    final (from, to) = presetRange(PeriodPreset.thisMonth, days: repository.days.values);
    return DailyLogState(
      from: from,
      to: to,
      printer: repository.printerHistory,
      date: yesterday,
      history: _history(repository),
      counter: day?.counter,
      note: day?.note ?? '',
      target: _startingTarget(repository),
      defaultTarget: repository.defaultTarget,
      suggested: repository.progress.suggested,
      formVersion: formVersion,
    );
  }

  /// Records with something from the daily log (records with only a shipment belong to the Shipped page),
  /// newest date first; records on the same date newest first.
  static List<Day> _history(TrackerRepository repository) =>
      repository.entries.values.where((d) => d.counter != null || d.target != null || d.note.isNotEmpty).toList()
        ..sort((a, b) => b.date != a.date ? b.date.compareTo(a.date) : b.id.compareTo(a.id));

  /// The default daily target; before one is set, the most recent day target or the suggestion.
  static int? _startingTarget(TrackerRepository repository) =>
      repository.defaultTarget ?? _history(repository).where((d) => d.target != null).firstOrNull?.target ?? repository.progress.suggested;

  /// Picking a date by hand leaves edit mode: a normal entry for that day, keeping the default target.
  void setDate(DateTime date) {
    final day = _repository.entryOn(ymd(date));
    emit(
      state.copyWith(
        date: date,
        counter: () => day?.counter,
        note: day?.note ?? '',
        target: () => _startingTarget(_repository),
        editing: () => null,
        formVersion: state.formVersion + 1,
      ),
    );
  }

  /// Loads a history entry into the form (on the Log tab); the target field becomes that day's own target.
  void editDay(Day day) => emit(
    state.copyWith(
      tab: LogTab.log,
      date: DateTime.parse(day.date),
      counter: () => day.counter,
      note: day.note,
      target: () => day.target,
      editing: () => day,
      formVersion: state.formVersion + 1,
    ),
  );

  /// Leaves edit mode: back to yesterday's counter and the default target, keeping the tab and History filter.
  void newEntry() {
    final fresh = _initial(_repository, formVersion: state.formVersion + 1);
    emit(fresh.copyWith(tab: state.tab, preset: state.preset, from: state.from, to: state.to));
  }

  void selectTab(LogTab tab) => emit(state.copyWith(tab: tab));

  void selectPreset(PeriodPreset preset) => emit(_withPeriod(state, preset: preset));

  void selectRange(DateTime from, DateTime to) {
    _custom = (from, to);
    emit(_withPeriod(state, preset: PeriodPreset.custom));
  }

  /// New entry: saves the counter and note for the day, and the target as the default for every day.
  /// Editing: replaces that day; an empty target means "use the default", a day left empty is removed.
  Future<void> save({required String counter, required String target, required String note}) async {
    final c = int.tryParse(counter.trim());
    final t = int.tryParse(target.trim());
    final n = note.trim();
    final key = ymd(state.date);
    // editing: the loaded record; new entry: the day's record (one per day for now), else a new one
    final existing = switch (state.editing) {
      final e? => _repository.entries[e.id] ?? e,
      null => _repository.entryOn(key) ?? Day(date: key),
    };

    if (state.editing != null) {
      if (c == null && t == null && n.isEmpty) {
        await deleteDay(existing.id);
      } else {
        await _repository.saveDay(existing.copyWith(counter: () => c, target: () => t, note: n));
      }
      return;
    }

    if (c != null || n.isNotEmpty) {
      await _repository.saveDay(existing.copyWith(counter: c == null ? null : () => c, note: n));
    }
    if (t != null && t != _repository.defaultTarget) await _repository.setDefaultTarget(t);
  }

  /// Log by scan: what the popup shows for a scanned code and production day.
  ScanLogDraft draftFromScan(String code, DateTime date) => _repository.scanLogDraft(code, date);

  /// Log by scan confirmed: records the scan and saves the counter; the form then shows that day.
  Future<void> saveScanLog(ScanLogDraft draft, int counter) async {
    await _repository.addScan(draft.code);
    await _repository.saveScanLog(draft, counter);
    setDate(draft.date);
  }

  /// Saves a printer counter reading for a production day; the day's Daily log counter is filled from it.
  Future<void> savePrinterReading({required DateTime date, required int value, required bool reset, required String note}) =>
      _repository.savePrinterReading(date: date, value: value, reset: reset, note: note);

  Future<void> deletePrinterReading(String id) => _repository.deletePrinterReading(id);

  /// Removes the record's log (counter, target, note); a shipment logged in it is kept.
  Future<void> deleteDay(String id) async {
    final day = _repository.entries[id];
    if (day?.shipped != null) {
      await _repository.saveDay(day!.copyWith(counter: () => null, target: () => null, note: ''));
    } else {
      await _repository.deleteDay(id);
    }
    if (state.editing?.id == id) newEntry();
  }
}
