import '../../../core/data/models.dart';

/// Outcome of one scan (camera or typed).
class ScanResult {
  const ScanResult({required this.scan, required this.total, this.previous, this.nextCode});

  final Scan scan;
  final int total;

  /// Scan of the highest code before this one.
  final Scan? previous;
  final String? nextCode;

  bool get inList => scan.pos != null;

  /// Codes printed since the highest code before this one ([previous]); negative when this code is behind it.
  /// Null when there is no previous scan or this one is not in the list.
  int? get sinceLast => inList && previous != null ? scan.pos! - previous!.pos! : null;
}

class ScanState {
  const ScanState({required this.hasCodes, this.invert = false, this.logMode = false, this.result, this.sessionCount = 0});

  final bool hasCodes;

  /// Laser marking often gives light-on-dark codes; the scanner must invert the image for those.
  final bool invert;

  /// Log by scan: each scanned code opens the counter popup instead of only checking the code.
  final bool logMode;

  /// Latest scan; replaced by each new one.
  final ScanResult? result;

  /// Codes recorded since this screen was opened.
  final int sessionCount;

  ScanState copyWith({bool? hasCodes, bool? invert, bool? logMode, ScanResult? Function()? result, int? sessionCount}) => ScanState(
        hasCodes: hasCodes ?? this.hasCodes,
        invert: invert ?? this.invert,
        logMode: logMode ?? this.logMode,
        result: result == null ? this.result : result(),
        sessionCount: sessionCount ?? this.sessionCount,
      );
}
