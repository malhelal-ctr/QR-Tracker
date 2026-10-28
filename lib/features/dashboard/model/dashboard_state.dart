import '../../../core/data/progress_stats.dart';
import '../../../core/data/stock_stats.dart';
import '../../../core/data/tracker_repository.dart';
import '../../../core/utils/period.dart';
import 'production_summary.dart';

class DashboardState {
  const DashboardState({
    required this.hasCodes,
    required this.fileName,
    required this.stats,
    required this.stock,
    required this.summary,
    required this.preset,
  });

  factory DashboardState.from(TrackerRepository repository, {required PeriodPreset preset, required DateTime from, required DateTime to}) =>
      DashboardState(
        hasCodes: repository.codes.isNotEmpty,
        fileName: repository.fileName,
        stats: repository.progress,
        stock: repository.stock,
        summary: ProductionSummary.compute(days: repository.days.values, defaultTarget: repository.defaultTarget, from: from, to: to),
        preset: preset,
      );

  final bool hasCodes;
  final String fileName;
  final ProgressStats stats;
  final StockStats stock;

  /// Daily log totals for the selected period.
  final ProductionSummary summary;
  final PeriodPreset preset;

  /// Whether the average daily output covers what is needed per day; null when either is unknown.
  bool? get onPace => stats.avg != null && stats.suggested != null ? stats.avg! >= stats.suggested! : null;

  bool get goalMet {
    final printed = stats.todayPrinted;
    final target = stats.target;
    return printed != null && target != null && target > 0 && printed >= target;
  }
}
