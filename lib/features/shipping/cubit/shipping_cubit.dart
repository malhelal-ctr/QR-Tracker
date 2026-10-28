import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/models.dart';
import '../../../core/data/repository_listener.dart';
import '../../../core/data/shipping_stats.dart';
import '../../../core/data/tracker_repository.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/period.dart';
import '../model/shipping_state.dart';

class ShippingCubit extends Cubit<ShippingState> with RepositoryListener {
  ShippingCubit(this._repository) : super(_initial(_repository)) {
    listenTo(_repository, () => emit(_refresh(state)));
  }

  final TrackerRepository _repository;

  /// The picked range while the preset is [PeriodPreset.custom].
  (DateTime, DateTime)? _custom;

  static ShippingState _initial(TrackerRepository repository) {
    final today = DateTime.now();
    const preset = PeriodPreset.last7Days;
    final (from, to) = presetRange(preset, days: repository.days.values);
    return ShippingState(
      date: today,
      shipped: repository.entryOn(ymd(today))?.shipped,
      stats: repository.shipping,
      period: ShippingPeriod.compute(days: repository.days.values, from: from, to: to),
      preset: preset,
      history: _history(repository),
    );
  }

  static List<Day> _history(TrackerRepository repository) =>
      repository.entries.values.where((d) => d.shipped != null).toList()..sort((a, b) => b.date != a.date ? b.date.compareTo(a.date) : b.id.compareTo(a.id));

  /// Recomputes everything that comes from the stored data, keeping the form and period choice.
  ShippingState _refresh(ShippingState s, {PeriodPreset? preset}) {
    final p = preset ?? s.preset;
    final (from, to) = p == PeriodPreset.custom && _custom != null ? _custom! : presetRange(p, days: _repository.days.values);
    return s.copyWith(
      stats: _repository.shipping,
      period: ShippingPeriod.compute(days: _repository.days.values, from: from, to: to),
      preset: p,
      history: _history(_repository),
    );
  }

  /// Picking a date by hand leaves edit mode; the field shows what is already logged for that day.
  void setDate(DateTime date) => emit(state.copyWith(
        date: date,
        shipped: () => _repository.entryOn(ymd(date))?.shipped,
        editing: () => null,
        formVersion: state.formVersion + 1,
      ));

  /// Loads a history entry into the form.
  void editDay(Day day) => emit(state.copyWith(
        date: DateTime.parse(day.date),
        shipped: () => day.shipped,
        editing: () => day,
        formVersion: state.formVersion + 1,
      ));

  /// Back to a new entry for today.
  void newEntry() => setDate(DateTime.now());

  /// Saves the shipped quantity for the form's day. Returns an error message, or null when saved.
  /// While editing, an empty field removes that day's shipment.
  Future<String?> save(String quantity) async {
    final qty = int.tryParse(quantity.trim());
    if (qty == null && state.editing == null) return 'Enter the number of products shipped';
    await _repository.setShipped(ymd(state.date), qty, id: state.editing?.id);
    if (qty == null) newEntry();
    return null;
  }

  /// Removes the shipment from a record (its counter and target stay).
  Future<void> delete(String id) async {
    final day = _repository.entries[id];
    if (day != null) await _repository.setShipped(day.date, null, id: id);
    if (state.editing?.id == id) newEntry();
  }

  void selectPreset(PeriodPreset preset) => emit(_refresh(state, preset: preset));

  void selectRange(DateTime from, DateTime to) {
    _custom = (from, to);
    emit(_refresh(state, preset: PeriodPreset.custom));
  }

  /// Printed lids counted in store today; null clears the starting balance.
  Future<void> setStartBalance(int? qty) => _repository.setShipStart(qty, DateTime.now());
}
