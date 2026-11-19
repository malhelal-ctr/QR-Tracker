import '../../../core/data/models.dart';
import '../../../core/data/tracker_repository.dart';

class MachineListState {
  const MachineListState({required this.machine, required this.fileName, required this.codeCount, required this.scanCount, required this.printed, required this.product, this.importedAt});

  factory MachineListState.from(TrackerRepository repository, LaserMachine machine) {
    final progress = repository.progressFor(machine);
    return MachineListState(
      machine: machine,
      fileName: repository.fileNameFor(machine),
      codeCount: repository.codesFor(machine).length,
      scanCount: repository.scansFor(machine).length,
      printed: progress.printed,
      product: repository.productFor(machine),
      importedAt: repository.importedAtFor(machine),
    );
  }

  final LaserMachine machine;
  final String fileName;
  final int codeCount;
  final int scanCount;
  final int printed;
  final String product;
  final int? importedAt;
  bool get hasList => codeCount > 0;
  bool get complete => hasList && printed >= codeCount;
}

class DataState {
  const DataState({
    required this.fileName,
    required this.codeCount,
    required this.scanCount,
    required this.periodEnd,
    this.importedAt,
    this.daysLeft,
    this.printed = 0,
    this.archived = const [],
    this.product = '',
    this.products = const [],
    this.busy = false,
    this.machineLists = const [],
  });

  factory DataState.from(TrackerRepository repository, {bool busy = false}) => DataState(
        fileName: repository.fileName,
        codeCount: repository.codes.length,
        scanCount: repository.scans.length,
        importedAt: repository.importedAt,
        periodEnd: repository.periodEnd,
        daysLeft: repository.progress.daysLeft,
        printed: repository.progress.printed,
        archived: repository.archivedLists,
        product: repository.product,
        products: repository.products,
        busy: busy,
        machineLists: [for (final machine in LaserMachine.values) MachineListState.from(repository, machine)],
      );

  final String fileName;
  final int codeCount;
  final int scanCount;
  final int? importedAt;

  /// yyyy-MM-dd, empty when not set.
  final String periodEnd;
  final int? daysLeft;

  /// Print position reached in the active list.
  final int printed;

  /// Finished lists, newest first.
  final List<ArchivedList> archived;

  /// Product of the active list, empty when none was set.
  final String product;

  /// Products used so far.
  final List<String> products;

  /// True while a file is being read for import.
  final bool busy;
  final List<MachineListState> machineLists;

  MachineListState batchFor(LaserMachine machine) => machineLists.firstWhere((b) => b.machine == machine);
  bool get hasAnyList => machineLists.any((b) => b.hasList);

  bool get hasList => codeCount > 0;

  /// The last code of the list has been scanned.
  bool get complete => hasList && printed >= codeCount;

  DataState copyWith({bool? busy}) => DataState(
        fileName: fileName,
        codeCount: codeCount,
        scanCount: scanCount,
        importedAt: importedAt,
        periodEnd: periodEnd,
        daysLeft: daysLeft,
        printed: printed,
        archived: archived,
        product: product,
        products: products,
        busy: busy ?? this.busy,
        machineLists: machineLists,
      );
}
