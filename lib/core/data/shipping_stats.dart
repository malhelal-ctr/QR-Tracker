import 'models.dart';

/// Printed lids in store: starting balance + printed (daily counters) − shipped, from the start date on.
class ShippingStats {
  const ShippingStats({
    required this.balance,
    required this.printed,
    required this.shipped,
    this.startQty,
    this.startDate = '',
    this.avgShipped,
    this.daysOfBuffer,
  });

  factory ShippingStats.compute({required Iterable<Day> days, int? startQty, String startDate = ''}) {
    // the start balance is counted in the morning, so that day's printing and shipping come after it
    final counted = days.where((d) => d.date.compareTo(startDate) >= 0).toList();
    final printed = counted.fold<int>(0, (a, d) => a + (d.counter ?? 0));
    final shipped = counted.fold<int>(0, (a, d) => a + (d.shipped ?? 0));
    final balance = (startQty ?? 0) + printed - shipped;

    final shipDays = days.where((d) => d.shipped != null).toList()..sort((a, b) => a.date.compareTo(b.date));
    final recent = shipDays.length > 7 ? shipDays.sublist(shipDays.length - 7) : shipDays;
    final avg = recent.isEmpty ? null : (recent.fold<int>(0, (a, d) => a + d.shipped!) / recent.length).round();

    return ShippingStats(
      balance: balance,
      printed: printed,
      shipped: shipped,
      startQty: startQty,
      startDate: startDate,
      avgShipped: avg,
      daysOfBuffer: avg != null && avg > 0 ? (balance / avg).floor() : null,
    );
  }

  /// Printed lids waiting in store now. Negative: more shipped than printed.
  final int balance;

  /// Printed and shipped since the start date (or since the first log).
  final int printed;
  final int shipped;

  final int? startQty;
  final String startDate;

  /// Average shipped per day over the last 7 days with shipments.
  final int? avgShipped;

  /// Whole days the store lasts at [avgShipped].
  final int? daysOfBuffer;
}

/// One day of the printed vs shipped comparison.
class ShipDay {
  const ShipDay({required this.date, this.printed, this.shipped});

  final DateTime date;
  final int? printed;
  final int? shipped;

  /// Printed − shipped (positive: printed more than shipped).
  int get difference => (printed ?? 0) - (shipped ?? 0);
}

/// Printed vs shipped for a date range (inclusive).
class ShippingPeriod {
  const ShippingPeriod({required this.from, required this.to, required this.days});

  factory ShippingPeriod.compute({required Iterable<Day> days, required DateTime from, required DateTime to}) {
    String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final start = key(from);
    final end = key(to);
    final inRange = days
        .where((d) => (d.counter != null || d.shipped != null) && d.date.compareTo(start) >= 0 && d.date.compareTo(end) <= 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return ShippingPeriod(
      from: from,
      to: to,
      days: [for (final d in inRange) ShipDay(date: DateTime.parse(d.date), printed: d.counter, shipped: d.shipped)],
    );
  }

  final DateTime from;
  final DateTime to;

  /// Days with printing or shipping, oldest first.
  final List<ShipDay> days;

  int get printed => days.fold(0, (a, d) => a + (d.printed ?? 0));
  int get shipped => days.fold(0, (a, d) => a + (d.shipped ?? 0));

  /// Printed − shipped: positive = over (store grows), negative = under (store shrinks).
  int get difference => printed - shipped;
}
