import 'models.dart';

/// What has been recorded for one product across its QR lists and daily log.
class ProductStats {
  const ProductStats({required this.name, this.lists = 0, this.codes = 0, this.days = 0, this.printed = 0, this.active = false});

  /// [activeCodes] is the size of the active list when it belongs to this product, else 0.
  factory ProductStats.compute({required String name, required int activeCodes, required Iterable<ArchivedList> archived, required Iterable<Day> records}) {
    final key = name.toLowerCase();
    final lists = archived.where((a) => a.product.toLowerCase() == key).toList();
    final logged = records.where((d) => d.counter != null && d.product.toLowerCase() == key).toList();
    return ProductStats(
      name: name,
      lists: lists.length + (activeCodes > 0 ? 1 : 0),
      codes: lists.fold<int>(activeCodes, (a, l) => a + l.total),
      days: logged.map((d) => d.date).toSet().length,
      printed: logged.fold<int>(0, (a, d) => a + d.counter!),
      active: activeCodes > 0,
    );
  }

  final String name;

  /// QR lists of this product, including the active one.
  final int lists;
  final int codes;

  /// Days with a counter logged for this product, and what those counters add up to.
  final int days;
  final int printed;

  /// The active QR list belongs to this product.
  final bool active;

  /// Lists or daily records point at this product, so it can't be deleted.
  bool get inUse => lists > 0 || days > 0;
}
