import 'models.dart';

/// Lid stock, kept simple:
///   last count + received − waste − every daily counter logged after that count
/// (one lid per printed code). Entries are applied in the order they were entered.
class StockStats {
  const StockStats({
    required this.hasData,
    required this.onHand,
    required this.usedSinceCount,
    required this.received,
    required this.wasted,
    this.lastCount,
    this.daysOfCover,
    this.coverUntil,
    this.shortfall = 0,
    this.lowStock,
  });

  factory StockStats.compute({
    required List<StockMove> moves,
    required Iterable<Day> days,
    required int remainingCodes,
    int? avgDailyUse,
    int? lowStock,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    if (moves.isEmpty) return StockStats(hasData: false, onHand: 0, usedSinceCount: 0, received: 0, wasted: 0, lowStock: lowStock);

    final sorted = [...moves]..sort((a, b) => a.ts.compareTo(b.ts));

    // a stock count resets the level; anything entered before it is already included in it
    var onHand = 0;
    var received = 0;
    var wasted = 0;
    StockMove? lastCount;
    for (final m in sorted) {
      switch (m.type) {
        case StockMoveType.count:
          onHand = m.qty;
          received = 0;
          wasted = 0;
          lastCount = m;
        case StockMoveType.received:
          onHand += m.qty;
          received += m.qty;
        case StockMoveType.waste:
          onHand -= m.qty;
          wasted += m.qty;
      }
    }

    // usage: daily counters logged after the count (or after the first stock entry when there is no count)
    final start = lastCount ?? sorted.first;
    bool loggedAfter(Day d) => d.counterAt != null ? d.counterAt! > start.ts : d.date.compareTo(start.date) >= 0;
    final used = days.where((d) => d.counter != null && loggedAfter(d)).fold<int>(0, (a, d) => a + d.counter!);
    onHand -= used;

    final daysOfCover = avgDailyUse != null && avgDailyUse > 0 ? (onHand / avgDailyUse).floor() : null;
    final today = DateTime(now.year, now.month, now.day);

    return StockStats(
      hasData: true,
      onHand: onHand,
      usedSinceCount: used,
      received: received,
      wasted: wasted,
      lastCount: lastCount,
      daysOfCover: daysOfCover,
      coverUntil: daysOfCover == null || daysOfCover < 0 ? null : today.add(Duration(days: daysOfCover)),
      shortfall: remainingCodes > onHand ? remainingCodes - onHand : 0,
      lowStock: lowStock,
    );
  }

  final bool hasData;

  /// Lids in stock now.
  final int onHand;

  /// Lids used (daily counters logged) since the last stock count, or since the first entry.
  final int usedSinceCount;
  final int received;
  final int wasted;
  final StockMove? lastCount;

  /// Whole days the stock lasts at the average daily use; null without usage history.
  final int? daysOfCover;
  final DateTime? coverUntil;

  /// Lids missing to finish the imported QR list (0 when there are enough).
  final int shortfall;

  /// Alert threshold set by the user.
  final int? lowStock;

  bool get isLow => lowStock != null && onHand <= lowStock!;
}
