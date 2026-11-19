import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/date_row.dart';
import '../../../core/widgets/field_label.dart';
import '../model/daily_log_state.dart';

typedef MachineReadings = ({int? laser1, bool reset1, int? laser2, bool reset2});

class MachineReadingSheet extends StatefulWidget {
  const MachineReadingSheet({super.key, required this.entry, required this.onSave, required this.onDate, required this.onClose});

  final LogEntry entry;
  final Future<void> Function(MachineReadings readings) onSave;
  final ValueChanged<String> onDate;
  final VoidCallback onClose;

  @override
  State<MachineReadingSheet> createState() => _MachineReadingSheetState();
}

class _MachineReadingSheetState extends State<MachineReadingSheet> {
  late final _total1 = TextEditingController(text: widget.entry.log?.total?.toString() ?? '');
  late final _total2 = TextEditingController(text: widget.entry.log?.total2?.toString() ?? '');
  late bool _reset1 = widget.entry.log?.totalReset ?? false;
  late bool _reset2 = widget.entry.log?.totalReset2 ?? false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _total1.addListener(_changed);
    _total2.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _total1.dispose();
    _total2.dispose();
    super.dispose();
  }

  int? _value(TextEditingController controller) => int.tryParse(controller.text.trim());

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave((laser1: _value(_total1), reset1: _reset1, laser2: _value(_total2), reset2: _reset2));
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

  List<Widget> _machineFields(LaserMachine machine, TextEditingController controller, bool reset, ValueChanged<bool> onReset) {
    final e = widget.entry;
    final total = _value(controller);
    final previous = e.previousTotalFor(machine);
    final previousDate = e.previousTotalDateFor(machine);
    final printed = e.log?.outputFor(machine);

    Widget info(IconData icon, String text, {Color color = C.onVariant}) => Padding(
          padding: EdgeInsets.only(top: 8.r),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18.r, color: color),
            SizedBox(width: 8.r),
            Expanded(child: Text(text, style: sans(14, color: color))),
          ]),
        );

    final List<Widget> check;
    if (reset) {
      check = [info(Icons.restart_alt, 'Counter reset: this reading starts again from 0.')];
    } else if (previous == null) {
      check = [info(Icons.info_outline, 'First reading: the next reading will be compared with it.')];
    } else if (total == null) {
      check = [info(Icons.history, 'Last reading ${fmt(previous)} on ${fmtDay(previousDate!)}')];
    } else if (total < previous) {
      check = [info(Icons.warning_amber_rounded, 'Lower than the last reading (${fmt(previous)}). Tick reset if the counter returned to 0.', color: C.warning)];
    } else {
      final moved = total - previous;
      check = [
        info(Icons.trending_up, 'Moved ${fmt(moved)} since ${fmtDay(previousDate!)}'),
        if (printed != null)
          moved == printed
              ? info(Icons.check_circle_outline, 'Matches the ${fmt(printed)} output logged for ${machine.label}', color: C.success)
              : info(Icons.compare_arrows, 'Daily output is ${fmt(printed)} (${fmtSigned(moved - printed)} difference).', color: C.warning),
      ];
    }

    return [
      FieldLabel('${machine.label} total counter'),
      TextField(
        controller: controller,
        autofocus: machine == LaserMachine.laser1 && e.log?.totalFor(machine) == null,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: mono(30, weight: FontWeight.w700),
        decoration: InputDecoration(hintText: previous == null ? 'e.g. 1482900' : 'after ${fmt(previous)}'),
      ),
      ...check,
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: reset,
        onChanged: (v) => onReset(v ?? false),
        title: Text('${machine.label} counter was reset', style: sans(14, weight: FontWeight.w600)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hadReading = widget.entry.log?.total != null || widget.entry.log?.total2 != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Icon(Icons.precision_manufacturing_outlined, color: C.primary, size: 24.r),
          SizedBox(width: 8.r),
          Expanded(child: Text(hadReading ? 'Edit machine readings' : 'Machine readings', style: sans(21, weight: FontWeight.w700))),
          IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close), tooltip: 'Close'),
        ]),
        Text('Enter both cumulative counters together. Daily output is not changed.', style: sans(13, color: C.onVariant)),
        SizedBox(height: 12.r),
        DateRow(label: 'Reading day', date: DateTime.parse(widget.entry.date), onTap: _pickDate),
        SizedBox(height: 16.r),
        ..._machineFields(LaserMachine.laser1, _total1, _reset1, (value) => setState(() => _reset1 = value)),
        Divider(height: 28.r),
        ..._machineFields(LaserMachine.laser2, _total2, _reset2, (value) => setState(() => _reset2 = value)),
        Text('Leave a field empty to remove that machine’s reading for this day.', style: sans(12, color: C.onVariant)),
        SizedBox(height: 12.r),
        BigButton(
          label: hadReading ? 'Save readings' : 'Log readings',
          icon: Icons.check_circle_outline,
          onPressed: _saving || (_value(_total1) == null && _value(_total2) == null && !hadReading) ? null : _save,
        ),
      ],
    );
  }
}
