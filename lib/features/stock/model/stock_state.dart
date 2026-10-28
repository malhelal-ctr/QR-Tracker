import '../../../core/data/models.dart';
import '../../../core/data/stock_stats.dart';

class StockState {
  const StockState({required this.stats, required this.history, required this.type, required this.date});

  final StockStats stats;

  /// Stock log, newest first.
  final List<StockMove> history;

  /// Kind of entry the form adds.
  final StockMoveType type;

  /// Date the form entry is for.
  final DateTime date;

  StockState copyWith({StockStats? stats, List<StockMove>? history, StockMoveType? type, DateTime? date}) => StockState(
        stats: stats ?? this.stats,
        history: history ?? this.history,
        type: type ?? this.type,
        date: date ?? this.date,
      );
}
