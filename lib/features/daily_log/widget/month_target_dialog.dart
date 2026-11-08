import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/month_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/field_label.dart';

/// What the user chose: save [dailyTarget] for the month, or go to the weekend & holidays settings.
typedef MonthPlan = ({int? dailyTarget, bool openSettings});

/// Edits a month's daily target and shows the month target it gives over the month's working days
/// (from the weekend & holidays settings). Resolves to null when cancelled.
Future<MonthPlan?> showMonthTargetDialog(BuildContext context, {required MonthSummary summary}) =>
    showDialog<MonthPlan>(context: context, builder: (_) => _MonthTargetDialog(summary));

class _MonthTargetDialog extends StatefulWidget {
  const _MonthTargetDialog(this.summary);

  final MonthSummary summary;

  @override
  State<_MonthTargetDialog> createState() => _MonthTargetDialogState();
}

class _MonthTargetDialogState extends State<_MonthTargetDialog> {
  late final _target = TextEditingController(text: widget.summary.dailyTarget?.toString() ?? '');

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final daily = int.tryParse(_target.text.trim());
    final days = s.workingDays;
    final off = s.days.length - days;
    final holidays = {for (final d in s.days) if (d.holiday != null && d.off) d.holiday!};

    return AlertDialog(
      title: Text('Plan for ${fmtMonth(s.month)}', style: sans(20, weight: FontWeight.w700)),
      content: SizedBox(
        width: 420.r,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Daily target (codes per working day)'),
              TextField(
                controller: _target,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: mono(24, weight: FontWeight.w700, color: C.success),
                decoration: const InputDecoration(hintText: 'e.g. 12000'),
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: 16.r),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(color: C.low, borderRadius: BorderRadius.circular(12.r)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    daily == null ? '$days working days — set a daily target to get the month target.' : 'Month target = ${fmt(daily)} × $days working days = ${fmt(daily * days)}',
                    style: mono(14, weight: FontWeight.w600),
                  ),
                  SizedBox(height: 6.r),
                  Text(
                    '$off days off this month${holidays.isEmpty ? '' : ' · holidays: ${holidays.join(', ')}'}',
                    style: sans(13, color: C.onVariant),
                  ),
                ]),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, (dailyTarget: null, openSettings: true)),
                  icon: const Icon(Icons.weekend_outlined),
                  label: const Text('WEEKEND & HOLIDAYS'),
                ),
              ),
              Text('Later months start with this target until you change it. Earlier months keep their own.', style: sans(12, color: C.onVariant)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(onPressed: () => Navigator.pop(context, (dailyTarget: daily, openSettings: false)), child: const Text('SAVE')),
      ],
    );
  }
}
