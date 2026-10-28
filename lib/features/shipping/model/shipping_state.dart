import '../../../core/data/models.dart';
import '../../../core/data/shipping_stats.dart';
import '../../../core/utils/period.dart';

class ShippingState {
  const ShippingState({
    required this.date,
    required this.stats,
    required this.period,
    required this.preset,
    required this.history,
    this.shipped,
    this.editing,
    this.formVersion = 0,
  });

  /// Day the form entry is for (today by default, or the day being edited).
  final DateTime date;

  /// Value to fill into the form.
  final int? shipped;

  /// History record loaded into the form; null for a new entry.
  final Day? editing;

  /// Bumped when [shipped] should be pushed into the text field.
  final int formVersion;

  /// Printed lids in store now.
  final ShippingStats stats;

  /// Printed vs shipped for the selected period.
  final ShippingPeriod period;
  final PeriodPreset preset;

  /// Records with a shipment, newest first.
  final List<Day> history;

  ShippingState copyWith({
    DateTime? date,
    int? Function()? shipped,
    Day? Function()? editing,
    int? formVersion,
    ShippingStats? stats,
    ShippingPeriod? period,
    PeriodPreset? preset,
    List<Day>? history,
  }) =>
      ShippingState(
        date: date ?? this.date,
        shipped: shipped == null ? this.shipped : shipped(),
        editing: editing == null ? this.editing : editing(),
        formVersion: formVersion ?? this.formVersion,
        stats: stats ?? this.stats,
        period: period ?? this.period,
        preset: preset ?? this.preset,
        history: history ?? this.history,
      );
}
