import 'models.dart';

/// Why a reading gives no printed amount.
enum PrinterGap {
  /// First reading of the printer: nothing earlier to subtract.
  first,

  /// Lower than the previous reading without being marked as a reset.
  wentDown,
}

/// A reading with what was printed since the printer's previous reading.
class PrinterStep {
  const PrinterStep({required this.reading, this.previous, this.printed, this.gap});

  final PrinterReading reading;
  final PrinterReading? previous;

  /// Codes printed since [previous]; null when [gap] says why it can't be worked out.
  final int? printed;
  final PrinterGap? gap;
}

/// Readings in order per printer (production day, then entry time), each with what was printed since
/// the one before: this reading − previous, or the whole reading after a reset.
List<PrinterStep> printerSteps(Iterable<PrinterReading> readings) {
  final sorted = readings.toList()..sort((a, b) => a.date != b.date ? a.date.compareTo(b.date) : a.ts.compareTo(b.ts));
  final last = <String, PrinterReading>{};
  final steps = <PrinterStep>[];
  for (final r in sorted) {
    final prev = last[r.printer];
    last[r.printer] = r;
    steps.add(switch (prev) {
      _ when r.reset => PrinterStep(reading: r, previous: prev, printed: r.value),
      null => PrinterStep(reading: r, gap: PrinterGap.first),
      final p when r.value < p.value => PrinterStep(reading: r, previous: p, gap: PrinterGap.wentDown),
      final p => PrinterStep(reading: r, previous: p, printed: r.value - p.value),
    });
  }
  return steps;
}

/// Printed per production day (yyyy-MM-dd), adding up every printer and every reading of the day.
/// Days whose readings give no printed amount (first reading, counter went down) are left out.
Map<String, int> printedByDay(Iterable<PrinterStep> steps) {
  final byDay = <String, int>{};
  for (final s in steps) {
    if (s.printed case final p?) byDay[s.reading.date] = (byDay[s.reading.date] ?? 0) + p;
  }
  return byDay;
}
