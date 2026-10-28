import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/models.dart';
import '../../../core/data/repository_listener.dart';
import '../../../core/data/tracker_repository.dart';
import '../../../core/utils/file_io.dart';
import '../../../core/utils/format.dart';
import '../model/data_state.dart';
import '../model/import_preview.dart';

class DataCubit extends Cubit<DataState> with RepositoryListener {
  DataCubit(this._repository) : super(DataState.from(_repository)) {
    listenTo(_repository, () => emit(DataState.from(_repository, busy: state.busy)));
  }

  final TrackerRepository _repository;

  /// Lets the user pick a CSV / TXT / XLSX file and reads its first column. Null if cancelled.
  Future<ImportPreview?> pickImportFile() async {
    emit(state.copyWith(busy: true));
    try {
      final picked = await pickFile(['csv', 'txt', 'xlsx']);
      if (picked == null) return null;
      final (name, bytes) = picked;
      final rows = parseCodes(name, bytes);
      if (rows.isEmpty) throw const FormatException('No codes found in the first column.');
      return ImportPreview.parse(name, rows);
    } finally {
      if (!isClosed) emit(state.copyWith(busy: false));
    }
  }

  /// Returns the number of codes imported.
  Future<int> importCodes(ImportPreview preview) async {
    await _repository.importCodes(preview.codes, preview.fileName, clearScans: preview.clearScans || !state.hasList);
    return preview.codes.length;
  }

  Future<void> setPeriodEnd(DateTime? date) => _repository.setPeriodEnd(date == null ? '' : ymd(date));

  /// Each export returns the saved file name, or null if the user cancelled.
  Future<String?> exportDailyLog() {
    final days = _repository.days.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return _save(
      'qr-daily-log-${ymd(DateTime.now())}.csv',
      toCsv([
        ['Date', 'Target', 'Printed (counter)', 'Difference', 'Shipped', 'Note'],
        for (final d in days)
          if (_repository.targetFor(d) case final target)
            [d.date, target, d.counter, d.counter != null && target != null ? d.counter! - target : '', d.shipped, d.note],
      ]),
      'text/csv',
    );
  }

  Future<String?> exportScans() {
    final total = _repository.codes.length;
    return _save(
      'qr-scans-${ymd(DateTime.now())}.csv',
      toCsv([
        ['Date time', 'Code', 'Position', 'Of total'],
        for (final s in _repository.scans) [DateTime.fromMillisecondsSinceEpoch(s.ts).toString().substring(0, 19), s.code, s.pos ?? 'NOT IN LIST', total],
      ]),
      'text/csv',
    );
  }

  Future<String?> exportStock() => _save(
        'qr-lid-stock-${ymd(DateTime.now())}.csv',
        toCsv([
          ['Date', 'Type', 'Lids', 'Note'],
          for (final m in _repository.stockMoves) [m.date, m.type.name, m.type == StockMoveType.waste ? -m.qty : m.qty, m.note],
        ]),
        'text/csv',
      );

  Future<String?> backup() => _save('qr-tracker-backup-${ymd(DateTime.now())}.json', _repository.backupJson(), 'application/json');

  /// Picks a backup file and returns its text, or null if cancelled. Call [restore] after the user confirms.
  Future<String?> pickBackup() async {
    final picked = await pickFile(['json']);
    return picked == null ? null : utf8.decode(picked.$2);
  }

  Future<void> restore(String json) => _repository.restore(json);

  Future<void> eraseAll() => _repository.resetAll();

  Future<String?> _save(String name, String text, String mime) async => await saveText(name, text, mime) ? name : null;
}
