import '../../../core/data/progress_stats.dart';
import '../../../core/data/models.dart';
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
    this.product = '',
    this.hasCodes2 = false,
    this.fileName2 = '',
    this.product2 = '',
    this.stats2,
  });

  factory DashboardState.from(TrackerRepository repository, {required PeriodPreset preset, required DateTime from, required DateTime to}) =>
      DashboardState(
        hasCodes: repository.codesFor(LaserMachine.laser1).isNotEmpty,
        hasCodes2: repository.codesFor(LaserMachine.laser2).isNotEmpty,
        fileName: repository.fileName,
        fileName2: repository.fileNameFor(LaserMachine.laser2),
        product: repository.product,
        product2: repository.productFor(LaserMachine.laser2),
        stats: repository.progress,
        stats2: repository.progressFor(LaserMachine.laser2),
        stock: repository.stock,
        summary: ProductionSummary.compute(days: repository.days.values, targetFor: repository.targetFor, from: from, to: to),
        preset: preset,
      );

  final bool hasCodes;
  final String fileName;
  final String product;
  final bool hasCodes2;
  final String fileName2;
  final String product2;
  final ProgressStats stats;
  final ProgressStats? stats2;
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
