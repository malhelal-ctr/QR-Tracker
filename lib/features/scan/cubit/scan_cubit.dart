import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/models.dart';
import '../../../core/data/repository_listener.dart';
import '../../../core/data/tracker_repository.dart';
import '../model/scan_state.dart';

/// Continuous scanning: every new code is recorded and replaces the shown result, the camera keeps running.
/// The screen opens on the last saved scan, so leaving the tab or the app doesn't lose it.
class ScanCubit extends Cubit<ScanState> with RepositoryListener {
  ScanCubit(this._repository) : super(ScanState(hasCodes: LaserMachine.values.any((m) => _repository.codesFor(m).isNotEmpty), result: _lastResult(_repository))) {
    // scans cleared (list archived, data erased or restored) take the shown result with them
    listenTo(
      _repository,
      () => emit(state.copyWith(
        hasCodes: LaserMachine.values.any((m) => _repository.codesFor(m).isNotEmpty),
        result: () => _lastResult(_repository),
      )),
    );
  }

  final TrackerRepository _repository;
  bool _busy = false;
  DateTime _lastCameraRead = DateTime.fromMillisecondsSinceEpoch(0);

  /// Pause between camera reads, so two codes in view don't flicker back and forth.
  static const cameraCooldown = Duration(milliseconds: 1200);

  /// The latest saved scan, compared with the highest code scanned before it; null before any scan.
  static ScanResult? _lastResult(TrackerRepository repository) {
    final scans = repository.scans;
    if (scans.isEmpty) return null;
    final earlier = scans.sublist(0, scans.length - 1).where((s) => s.pos != null && s.machine == scans.last.machine);
    return _result(repository, scans.last, earlier.fold<Scan?>(null, (a, s) => a == null || s.pos! > a.pos! ? s : a));
  }

  static ScanResult _result(TrackerRepository repository, Scan scan, Scan? previous) => ScanResult(
        scan: scan,
        total: repository.codesFor(scan.machine).length,
        previous: previous,
        nextCode: scan.pos == null ? null : repository.codeAfter(scan.pos!, machine: scan.machine),
        product: repository.productFor(scan.machine),
      );

  /// Records a scanned or typed code and shows where the machine is.
  /// Camera reads of the code already shown, or too soon after the last read, are ignored.
  Future<void> submit(String text, {bool fromCamera = false, LaserMachine? machine}) async {
    final code = text.trim();
    if (_busy || code.isEmpty) return;
    if (fromCamera) {
      final now = DateTime.now();
      if ((code == state.result?.scan.code && (machine == null || machine == state.result?.scan.machine)) || now.difference(_lastCameraRead) < cameraCooldown) return;
      _lastCameraRead = now;
    }
    _busy = true;
    try {
      final matches = _repository.machinesForCode(code);
      machine ??= matches.length == 1 ? matches.single : null;
      final selected = machine ?? LaserMachine.laser1;
      final previous = _repository.highestScanFor(selected);
      final scan = await _repository.addScan(code, machine: selected);
      final result = _result(_repository, scan, previous);
      if (!isClosed) emit(state.copyWith(result: () => result, sessionCount: state.sessionCount + 1));
    } finally {
      _busy = false;
    }
  }

  void setInvert(bool value) => emit(state.copyWith(invert: value));

  void setLogMode(bool value) => emit(state.copyWith(logMode: value));
}
