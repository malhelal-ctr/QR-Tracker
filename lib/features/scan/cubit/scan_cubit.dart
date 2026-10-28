import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/repository_listener.dart';
import '../../../core/data/tracker_repository.dart';
import '../model/scan_state.dart';

/// Continuous scanning: every new code is recorded and replaces the shown result, the camera keeps running.
class ScanCubit extends Cubit<ScanState> with RepositoryListener {
  ScanCubit(this._repository) : super(ScanState(hasCodes: _repository.codes.isNotEmpty)) {
    listenTo(_repository, () => emit(state.copyWith(hasCodes: _repository.codes.isNotEmpty)));
  }

  final TrackerRepository _repository;
  bool _busy = false;
  DateTime _lastCameraRead = DateTime.fromMillisecondsSinceEpoch(0);

  /// Pause between camera reads, so two codes in view don't flicker back and forth.
  static const cameraCooldown = Duration(milliseconds: 1200);

  /// Records a scanned or typed code and shows where the machine is.
  /// Camera reads of the code already shown, or too soon after the last read, are ignored.
  Future<void> submit(String text, {bool fromCamera = false}) async {
    final code = text.trim();
    if (_busy || code.isEmpty) return;
    if (fromCamera) {
      final now = DateTime.now();
      if (code == state.result?.scan.code || now.difference(_lastCameraRead) < cameraCooldown) return;
      _lastCameraRead = now;
    }
    _busy = true;
    try {
      final previous = _repository.highestScan;
      final scan = await _repository.addScan(code);
      final result = ScanResult(
        scan: scan,
        total: _repository.codes.length,
        previous: previous,
        nextCode: scan.pos == null ? null : _repository.codeAfter(scan.pos!),
      );
      if (!isClosed) emit(state.copyWith(result: () => result, sessionCount: state.sessionCount + 1));
    } finally {
      _busy = false;
    }
  }

  void setInvert(bool value) => emit(state.copyWith(invert: value));

  void setLogMode(bool value) => emit(state.copyWith(logMode: value));
}
