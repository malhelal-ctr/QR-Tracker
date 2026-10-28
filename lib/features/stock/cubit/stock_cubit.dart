import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/models.dart';
import '../../../core/data/repository_listener.dart';
import '../../../core/data/tracker_repository.dart';
import '../model/stock_state.dart';

class StockCubit extends Cubit<StockState> with RepositoryListener {
  StockCubit(this._repository)
      : super(StockState(stats: _repository.stock, history: _history(_repository), type: StockMoveType.received, date: DateTime.now())) {
    listenTo(_repository, () => emit(state.copyWith(stats: _repository.stock, history: _history(_repository))));
  }

  final TrackerRepository _repository;

  static List<StockMove> _history(TrackerRepository repository) => repository.stockMoves.reversed.toList();

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

  /// Null turns the low-stock alert off.
  Future<void> setLowStock(int? lids) => _repository.setLowStock(lids);
}
