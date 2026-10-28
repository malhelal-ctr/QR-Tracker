import '../../../core/data/models.dart';
import '../../../core/data/printer_stats.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/period.dart';

/// Log page tabs: the morning entry with recent days, the full history with a date filter,
/// and printer counter readings.
enum LogTab { log, history, printer }

class DailyLogState {
  const DailyLogState({
    required this.date,
    required this.history,
    this.counter,
    this.note = '',
    this.target,
    this.defaultTarget,
    this.suggested,
    this.editing,
    this.formVersion = 0,
    this.tab = LogTab.log,
    this.preset = PeriodPreset.thisMonth,
    required this.from,
    required this.to,
    this.printer = const [],
  });

  /// Production day the counter and note belong to (yesterday by default, or the day being edited).
  final DateTime date;

  /// Values to fill into the form.
  final int? counter;
  final String note;

  /// New entry: the default daily target. Editing: that day's own target (null = uses the default).
  final int? target;

  /// Daily target used for every day without its own.
  final int? defaultTarget;

  /// Codes per day needed to finish the list by the period end.
  final int? suggested;

  /// Log records, newest date first.
  final List<Day> history;

  /// History record loaded into the form; null for a normal new entry.
  final Day? editing;

  /// Bumped when the values above should be pushed into the text fields.
  final int formVersion;

  final LogTab tab;

  /// History tab date filter.
  final PeriodPreset preset;
  final DateTime from;
  final DateTime to;

  /// Printer counter readings with what each one printed, oldest first.
  final List<PrinterStep> printer;

  /// Days shown under the form on the Log tab.
  static const recentCount = 7;

  List<Day> get recent => history.take(recentCount).toList();

  /// History within [from]–[to], newest first.
  List<Day> get filtered {
    final a = ymd(from), b = ymd(to);
    return history.where((d) => d.date.compareTo(a) >= 0 && d.date.compareTo(b) <= 0).toList();
  }

  /// Totals for [filtered]: printed and average per day over days with a counter; [met] of [withTarget] days hit their target.
  ({int printed, int logged, int? avg, int met, int withTarget}) get summary {
    // per date, so several records on one day count as one day
    final days = Day.mergeByDate(filtered.reversed).values;
    final counted = days.where((d) => d.counter != null).toList();
    final printed = counted.fold(0, (a, d) => a + d.counter!);
    final targeted = counted.where((d) => targetFor(d) != null).toList();
    return (
      printed: printed,
      logged: counted.length,
      avg: counted.isEmpty ? null : (printed / counted.length).round(),
      met: targeted.where((d) => d.counter! >= targetFor(d)!).length,
      withTarget: targeted.length,
    );
  }

  /// The day's own target, else the default.
  int? targetFor(Day day) => day.target ?? defaultTarget;

  DailyLogState copyWith({
    DateTime? date,
    List<Day>? history,
    int? Function()? counter,
    String? note,
    int? Function()? target,
    int? Function()? defaultTarget,
    int? Function()? suggested,
    Day? Function()? editing,
    int? formVersion,
    LogTab? tab,
    PeriodPreset? preset,
    DateTime? from,
    DateTime? to,
    List<PrinterStep>? printer,
  }) => DailyLogState(
    date: date ?? this.date,
    history: history ?? this.history,
    counter: counter == null ? this.counter : counter(),
    note: note ?? this.note,
    target: target == null ? this.target : target(),
    defaultTarget: defaultTarget == null ? this.defaultTarget : defaultTarget(),
    suggested: suggested == null ? this.suggested : suggested(),
    editing: editing == null ? this.editing : editing(),
    formVersion: formVersion ?? this.formVersion,
    tab: tab ?? this.tab,
    preset: preset ?? this.preset,
    from: from ?? this.from,
    to: to ?? this.to,
    printer: printer ?? this.printer,
  );
}
