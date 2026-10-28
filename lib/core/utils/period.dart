import '../data/models.dart';

/// Quick choices for a reporting period.
enum PeriodPreset { last7Days, thisWeek, thisMonth, all, custom }

/// Date range for a preset, ending today. [all] starts at the first logged day.
(DateTime, DateTime) presetRange(PeriodPreset preset, {required Iterable<Day> days, DateTime? now}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (preset) {
    PeriodPreset.last7Days => (today.subtract(const Duration(days: 6)), today),
    // weeks start on Monday
    PeriodPreset.thisWeek => (today.subtract(Duration(days: today.weekday - 1)), today),
    PeriodPreset.thisMonth => (DateTime(today.year, today.month), today),
    PeriodPreset.all || PeriodPreset.custom => (
        days.isEmpty ? today : DateTime.parse((days.map((d) => d.date).toList()..sort()).first),
        today,
      ),
  };
}
