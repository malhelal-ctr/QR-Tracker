import '../../../core/data/tracker_repository.dart';

class DataState {
  const DataState({
    required this.fileName,
    required this.codeCount,
    required this.scanCount,
    required this.periodEnd,
    this.importedAt,
    this.daysLeft,
    this.busy = false,
  });

  factory DataState.from(TrackerRepository repository, {bool busy = false}) => DataState(
        fileName: repository.fileName,
        codeCount: repository.codes.length,
        scanCount: repository.scans.length,
        importedAt: repository.importedAt,
        periodEnd: repository.periodEnd,
        daysLeft: repository.progress.daysLeft,
        busy: busy,
      );

  final String fileName;
  final int codeCount;
  final int scanCount;
  final int? importedAt;

  /// yyyy-MM-dd, empty when not set.
  final String periodEnd;
  final int? daysLeft;

  /// True while a file is being read for import.
  final bool busy;

  bool get hasList => codeCount > 0;

  DataState copyWith({bool? busy}) => DataState(
        fileName: fileName,
        codeCount: codeCount,
        scanCount: scanCount,
        importedAt: importedAt,
        periodEnd: periodEnd,
        daysLeft: daysLeft,
        busy: busy ?? this.busy,
      );
}
