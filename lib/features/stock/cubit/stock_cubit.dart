import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/models.dart';
import '../../../core/data/repository_listener.dart';
import '../../../core/data/tracker_repository.dart';
import '../model/stock_state.dart';

class StockCubit extends Cubit<StockState> with RepositoryListener {
  StockCubit(this._repository) : super(_read(_repository, StockState(stats: _repository.stock, history: const [], type: StockMoveType.received, date: DateTime.now()))) {
    listenTo(_repository, () => emit(_read(_repository, state)));
  }

  final TrackerRepository _repository;

  static StockState _read(TrackerRepository repository, StockState state) => state.copyWith(
        stats: repository.stock,
        history: repository.stockMoves.reversed.toList(),
        leadTime: repository.lidLeadTime,
        notify: repository.lidNotify,
        notifyAt: repository.lidNotifyAt,
      );

  void setType(StockMoveType type) => emit(state.copyWith(type: type));

  void setDate(DateTime date) => emit(state.copyWith(date: date));

  /// Adds the form entry. Returns an error message, or null when saved.
  Future<String?> add(String quantity, String note) async {
    final qty = int.tryParse(quantity.trim());
    if (qty == null || qty < 0 || (qty == 0 && state.type != StockMoveType.count)) return 'Enter the number of lids';
    await _repository.addStockMove(state.type, qty, state.date, note: note.trim());
    return null;
  }

  Future<void> delete(int ts) => _repository.deleteStockMove(ts);

  /// Null turns the minimum-lids warning off.
  Future<void> setLowStock(int? lids) => _repository.setLowStock(lids);

  Future<void> setLeadTime(int days) => _repository.setLidLeadTime(days);

  Future<void> setNotify(bool on, int? minutes) => _repository.setLidNotify(on: on, minutes: minutes);
}
