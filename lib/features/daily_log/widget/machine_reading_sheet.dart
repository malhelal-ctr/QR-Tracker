import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/date_row.dart';
import '../../../core/widgets/field_label.dart';
import '../model/daily_log_state.dart';

/// A machine reading: the machine's total counter on a day, and whether it was reset before it.
/// Saving it changes only the reading, never the day's printed count (the daily log).
class MachineReadingSheet extends StatefulWidget {
  const MachineReadingSheet({super.key, required this.entry, required this.onSave, required this.onDate, required this.onClose});

  final LogEntry entry;

  /// Null total removes the reading.
  final Future<void> Function(int? total, bool reset) onSave;
  final ValueChanged<String> onDate;
  final VoidCallback onClose;

  @override
  State<MachineReadingSheet> createState() => _MachineReadingSheetState();
}

class _MachineReadingSheetState extends State<MachineReadingSheet> {
  late final _total = TextEditingController(text: widget.entry.log?.total?.toString() ?? '');
  late bool _reset = widget.entry.log?.totalReset ?? false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _total.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _total.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_total.text.trim());

  Future<void> _save(int? total) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(total, _reset);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(widget.entry.date),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) widget.onDate(ymd(d));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final prev = e.previousTotal;
    final total = _value;
    final hadReading = e.log?.total != null;
    final printed = e.log?.counter;

    Widget info(IconData icon, String text, {Color color = C.onVariant}) => Padding(
          padding: EdgeInsets.only(top: 8.r),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18.r, color: color),
            SizedBox(width: 8.r),
            Expanded(child: Text(text, style: sans(14, color: color))),
          ]),
        );

    // how far the counter moved since the previous reading, and how that compares with the daily log
    final List<Widget> lines;
    if (_reset) {
      lines = [info(Icons.restart_alt, 'Counter reset: this reading starts again from 0, so it isn’t compared with the reading before.')];
    } else if (prev == null) {
      lines = [info(Icons.info_outline, 'First reading: the next ones are compared with it.')];
    } else if (total == null) {
      lines = [info(Icons.history, 'Last reading ${fmt(prev)} on ${fmtDay(e.previousTotalDate!)}')];
    } else if (total < prev) {
      lines = [info(Icons.warning_amber_rounded, 'Lower than the last reading (${fmt(prev)}). Was the counter reset? Tick the box below.', color: C.warning)];
    } else {
      final moved = total - prev;
      lines = [
        info(Icons.trending_up, 'Moved ${fmt(moved)} since ${fmtDay(e.previousTotalDate!)} (${fmt(prev)})'),
        if (printed != null)
          moved == printed
              ? info(Icons.check_circle_outline, 'Matches the ${fmt(printed)} printed in the daily log', color: C.success)
              : info(Icons.compare_arrows, 'Daily log for this day says ${fmt(printed)} printed (${fmtSigned(moved - printed)}). The daily log isn’t changed.',
                  color: C.warning),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Icon(Icons.precision_manufacturing_outlined, color: C.primary, size: 24.r),
          SizedBox(width: 8.r),
          Expanded(child: Text(hadReading ? 'Edit machine reading' : 'Machine reading', style: sans(21, weight: FontWeight.w700))),
          IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close), tooltip: 'Close'),
        ]),
        Text('The machine’s total counter. Your daily printing log is not changed.', style: sans(13, color: C.onVariant)),
        SizedBox(height: 12.r),
        DateRow(label: 'Reading day', date: DateTime.parse(e.date), onTap: _pickDate),
        SizedBox(height: 16.r),
        const FieldLabel('Total counter'),
        TextField(
          controller: _total,
          autofocus: !hadReading,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: mono(34, weight: FontWeight.w700),
          decoration: InputDecoration(hintText: prev == null ? 'e.g. 1482900' : 'after ${fmt(prev)}'),
        ),
        ...lines,
        SizedBox(height: 8.r),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _reset,
          onChanged: (v) => setState(() => _reset = v ?? false),
          title: Text('The counter was reset', style: sans(15, weight: FontWeight.w600)),
          subtitle: Text('Tick when the machine’s total was set back to 0 before this reading', style: sans(12, color: C.onVariant)),
        ),
        SizedBox(height: 12.r),
        BigButton(
          label: hadReading ? 'Save reading' : 'Log reading',
          icon: Icons.check_circle_outline,
          onPressed: _saving || total == null ? null : () => _save(total),
        ),
        if (hadReading) ...[
          SizedBox(height: 4.r),
          TextButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    if (await confirm(context, 'Delete this reading?', '${fmtDay(e.date)} · ${fmt(e.log!.total)}', 'Delete')) await _save(null);
                  },
            icon: const Icon(Icons.delete_outline, color: C.danger),
            label: Text('DELETE READING', style: mono(12, weight: FontWeight.w700, color: C.danger)),
          ),
        ],
      ],
    );
  }
}
