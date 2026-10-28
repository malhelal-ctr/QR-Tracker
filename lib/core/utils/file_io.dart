import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

/// Reads the first column of a CSV / TXT / XLSX file. Values are kept as text so leading zeros survive.
List<String> parseCodes(String fileName, Uint8List bytes) {
  if (fileName.toLowerCase().endsWith('.xlsx')) {
    final sheet = Excel.decodeBytes(bytes).tables.values.first;
    return [
      for (final row in sheet.rows)
        row.map((c) => c?.value?.toString().trim() ?? '').firstWhere((v) => v.isNotEmpty, orElse: () => ''),
    ].where((v) => v.isNotEmpty).toList();
  }
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  return const LineSplitter().convert(text).map(_firstField).where((v) => v.isNotEmpty).toList();
}

String _firstField(String line) {
  final l = line.trim();
  if (l.startsWith('"')) {
    final buf = StringBuffer();
    for (var i = 1; i < l.length; i++) {
      if (l[i] == '"') {
        if (i + 1 < l.length && l[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          break;
        }
      } else {
        buf.write(l[i]);
      }
    }
    return buf.toString().trim();
  }
  final sep = RegExp(r'[,;\t]').firstMatch(l);
  return (sep == null ? l : l.substring(0, sep.start)).trim();
}

bool looksLikeHeader(List<String> rows) {
  if (rows.isEmpty) return false;
  final first = rows.first;
  if (RegExp(r'^(qr|qr ?codes?|codes?|serials?|serial ?no|sn|ids?|data|values?)$', caseSensitive: false).hasMatch(first)) return true;
  // a first row without digits above rows with digits is almost certainly a header
  final digit = RegExp(r'\d');
  return rows.length > 1 && !digit.hasMatch(first) && digit.hasMatch(rows[1]);
}

String toCsv(List<List<Object?>> rows) {
  String cell(Object? v) {
    final s = v?.toString() ?? '';
    return RegExp(r'[",\r\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  return '﻿${rows.map((r) => r.map(cell).join(',')).join('\r\n')}';
}

/// Save dialog on Android, download on web. Returns false if the user cancelled.
Future<bool> saveText(String fileName, String text, String mimeType) async {
  final uri = await FilePicker.saveFile(fileName: fileName, bytes: Uint8List.fromList(utf8.encode(text)), mimeType: mimeType);
  return uri != null;
}

/// Lets the user pick one file and returns its name and bytes, or null if cancelled.
Future<(String, Uint8List)?> pickFile(List<String> extensions) async {
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: extensions);
  if (files.isEmpty) return null;
  final f = files.first;
  return (f.name, await f.xFile.readAsBytes());
}
