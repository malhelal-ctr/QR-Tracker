import '../../../core/utils/file_io.dart';
import '../../../core/data/models.dart';

/// A picked QR list file, before it is imported.
class ImportPreview {
  const ImportPreview({required this.fileName, required this.rows, required this.hasHeader, this.clearScans = true, this.product = '', this.machine = LaserMachine.laser1});

  factory ImportPreview.parse(String fileName, List<String> rows) => ImportPreview(fileName: fileName, rows: rows, hasHeader: looksLikeHeader(rows));

  final String fileName;

  /// First-column values, including a possible header row.
  final List<String> rows;
  final bool hasHeader;

  /// Old scans point at positions in the old list, so they are cleared by default.
  final bool clearScans;

  /// Product the codes are printed for.
  final String product;
  final LaserMachine machine;

  List<String> get codes => hasHeader ? rows.sublist(1) : rows;

  int get duplicates => codes.length - codes.toSet().length;

  ImportPreview copyWith({bool? hasHeader, bool? clearScans, String? product, LaserMachine? machine}) => ImportPreview(
        fileName: fileName,
        rows: rows,
        hasHeader: hasHeader ?? this.hasHeader,
        clearScans: clearScans ?? this.clearScans,
        product: product ?? this.product,
        machine: machine ?? this.machine,
      );
}
