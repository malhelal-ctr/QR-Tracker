import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/date_row.dart';
import '../../../core/widgets/field_label.dart';
import '../../../core/widgets/stepper_field.dart';

/// Enter the printer's QR counter; shows what was printed since the last reading before saving.
class PrinterForm extends StatefulWidget {
  const PrinterForm({super.key, required this.last, required this.onSave});

  /// The printer's latest reading, to subtract from; null before the first one.
  final PrinterReading? last;
  final Future<void> Function({required DateTime date, required int value, required bool reset, required String note}) onSave;

  @override
  State<PrinterForm> createState() => _PrinterFormState();
}

class _PrinterFormState extends State<PrinterForm> {
  // the reading covers yesterday's printing by default, like the morning log
  DateTime _date = DateTime.now().subtract(const Duration(days: 1));
  final _value = TextEditingController();
  final _note = TextEditingController();
  bool _reset = false;

  @override
  void initState() {
    super.initState();
    _value.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now(), helpText: 'Production day');
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final value = int.tryParse(_value.text);
    if (value == null) return showSnack(context, 'Enter the printer counter', error: true);
    await widget.onSave(date: _date, value: value, reset: _reset, note: _note.text.trim());
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    showSnack(context, 'Printer reading saved');
    setState(() {
      _value.clear();
      _note.clear();
      _reset = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.last;
    final value = int.tryParse(_value.text);
    final printed = value == null ? null : (_reset ? value : (last == null ? null : value - last.value));

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Printer counter', icon: Icons.print_outlined, trailing: Pill(PrinterReading.defaultPrinter)),
          DateRow(label: 'Production day', date: _date, onTap: _pickDate),
          SizedBox(height: 16.r),
          const FieldLabel('Counter on the printer'),
          StepperField(controller: _value, color: C.primary, step: 1),
          SizedBox(height: 10.r),
          Tile(
            color: C.lowest,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                last == null ? 'First reading: the next one will show what was printed.' : 'Last reading ${fmt(last.value)} · ${fmtDay(last.date)}',
                style: sans(14, color: C.onVariant),
              ),
              if (printed != null) ...[
                SizedBox(height: 4.r),
                Text(
                  printed < 0 ? 'Lower than the last reading. Was the counter reset?' : 'Printed: ${fmt(printed)} → counter for ${fmtDate(_date)}',
                  style: sans(15, weight: FontWeight.w700, color: printed < 0 ? C.warning : C.success),
                ),
              ],
            ]),
          ),
          SizedBox(height: 8.r),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _reset,
            onChanged: (v) => setState(() => _reset = v),
            title: Text('Counter was reset', style: sans(15, weight: FontWeight.w600)),
            subtitle: Text('Turn on if the printer counter started again from 0 before this reading', style: sans(13, color: C.onVariant)),
          ),
          const FieldLabel('Note (optional)'),
          TextField(controller: _note, decoration: const InputDecoration(hintText: 'e.g. New ribbon')),
          SizedBox(height: 16.r),
          BigButton(label: 'Save reading', icon: Icons.check_circle_outline, onPressed: _save),
        ],
      ),
    );
  }
}
