import '../../../core/data/models.dart';
import '../../../core/data/stock_stats.dart';

class StockState {
  const StockState({
    required this.stats,
    required this.history,
    required this.type,
    required this.date,
    this.leadTime = 2,
    this.notify = true,
    this.notifyAt = 8 * 60,
  });

  final StockStats stats;

  /// Stock log, newest first.
  final List<StockMove> history;

  /// Kind of entry the form adds.
  final StockMoveType type;

  /// Date the form entry is for.
  final DateTime date;

  /// Working days needed to get new lids after ordering.
  final int leadTime;

  /// Low-stock phone notification on, and its time (minutes after midnight).
  final bool notify;
  final int notifyAt;

  StockState copyWith({
    StockStats? stats,
    List<StockMove>? history,
    StockMoveType? type,
    DateTime? date,
    int? leadTime,
    bool? notify,
    int? notifyAt,
  }) => StockState(
        stats: stats ?? this.stats,
        history: history ?? this.history,
        type: type ?? this.type,
        date: date ?? this.date,
        leadTime: leadTime ?? this.leadTime,
        notify: notify ?? this.notify,
        notifyAt: notifyAt ?? this.notifyAt,
      );
}
