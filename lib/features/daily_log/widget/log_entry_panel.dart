import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/month_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/date_row.dart';
import '../../../core/widgets/field_label.dart';
import '../../../core/widgets/product_field.dart';
import '../../../core/widgets/stepper_field.dart';
import '../model/daily_log_state.dart';

/// What the user entered for a day.
typedef LogInput = ({int? counter, int? total, bool totalReset, int? target, String note, String product});

/// The day's log: printed today and the machine total, checked against each other, plus note and target.
/// Shown beside the month on a wide screen, or in a bottom sheet on a phone.
class LogEntryPanel extends StatefulWidget {
  const LogEntryPanel({
    super.key,
    required this.entry,
    required this.products,
    required this.onSave,
    required this.onDelete,
    required this.onDate,
    required this.onOffChanged,
    required this.onClose,
    this.onScan,
  });

  final LogEntry entry;
  final List<String> products;
  final Future<void> Function(LogInput input) onSave;
  final Future<void> Function() onDelete;
  final ValueChanged<String> onDate;
  final ValueChanged<bool> onOffChanged;
  final VoidCallback onClose;

  /// Log by scan; null hides the button.
  final VoidCallback? onScan;

  @override
  State<LogEntryPanel> createState() => _LogEntryPanelState();
}

class _LogEntryPanelState extends State<LogEntryPanel> {
  late final _counter = TextEditingController(text: widget.entry.log?.counter?.toString() ?? '');
  late final _total = TextEditingController(text: widget.entry.log?.total?.toString() ?? '');
  late final _note = TextEditingController(text: widget.entry.log?.note ?? '');
  late final _target = TextEditingController(text: widget.entry.log?.target?.toString() ?? '');
  late bool _reset = widget.entry.log?.totalReset ?? false;
  late bool _ownTarget = widget.entry.log?.target != null;
  late String _product = widget.entry.product;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _counter.addListener(_changed);
    _total.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _counter.dispose();
    _total.dispose();
    _note.dispose();
    _target.dispose();
    super.dispose();
  }

  int? get _printedValue => int.tryParse(_counter.text.trim());
  int? get _totalValue => int.tryParse(_total.text.trim());

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave((
        counter: _printedValue,
        total: _totalValue,
        totalReset: _reset,
        target: _ownTarget ? int.tryParse(_target.text.trim()) : null,
        note: _note.text,
        product: _product,
      ));
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

  /// The line under the machine total: whether it agrees with the day before + printed today,
  /// or the number either field can be filled with.
  Widget _check() {
    final e = widget.entry;
    final prev = e.previousTotal;
    final printed = _printedValue;
    final total = _totalValue;

    Widget note(IconData icon, Color color, String text, {String? use, VoidCallback? onUse}) => Padding(
          padding: EdgeInsets.only(top: 8.r),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(icon, size: 18.r, color: color),
            SizedBox(width: 8.r),
            Expanded(child: Text(text, style: sans(13, color: color))),
            if (onUse != null) TextButton(onPressed: onUse, child: Text(use!, style: mono(12, weight: FontWeight.w700, color: C.primary))),
          ]),
        );

    if (prev == null) {
      return note(Icons.info_outline, C.onVariant, 'No earlier machine total yet — the check starts from the next day.');
    }
    final since = 'total on ${fmtDay(e.previousTotalDate!)}: ${fmt(prev)}';
    if (total == null && printed != null) {
      return note(Icons.calculate_outlined, C.onVariant, 'Expected total ${fmt(prev + printed)} ($since)',
          use: 'USE', onUse: () => _total.text = '${prev + printed}');
    }
    if (total != null && printed == null && !_reset && total >= prev) {
      return note(Icons.calculate_outlined, C.onVariant, 'Printed by the total: ${fmt(total - prev)} ($since)',
          use: 'USE', onUse: () => _counter.text = '${total - prev}');
    }
    if (total == null) return note(Icons.info_outline, C.onVariant, 'Previous $since');
    if (_reset) return note(Icons.restart_alt, C.onVariant, 'Machine total was reset — not checked against $since');
    final gap = totalGap(previousTotal: prev, printed: printed, total: total);
    if (gap == 0) return note(Icons.check_circle_outline, C.success, 'Matches: ${fmt(prev)} + ${fmt(printed)} = ${fmt(total)}');
    if (total < prev) return note(Icons.warning_amber_rounded, C.warning, 'Lower than the $since. Was the machine total reset?');
    if (gap == null) return note(Icons.info_outline, C.onVariant, 'Previous $since');
    return note(
      Icons.warning_amber_rounded,
      C.warning,
      'Total is ${fmt(gap.abs())} ${gap > 0 ? 'higher' : 'lower'} than expected (${fmt(prev)} + ${fmt(printed)} = ${fmt(prev + printed!)}). '
      '${gap > 0 ? 'Is a day missing, or ' : 'Is '}a number wrong?',
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final date = DateTime.parse(e.date);
    final prev = e.previousTotal;
    final total = _totalValue;
    final showReset = _reset || (prev != null && total != null && total < prev);

    final printed = [
      const FieldLabel('Printed today (counter before reset)'),
      StepperField(controller: _counter, color: C.primary),
      if (widget.onScan != null) ...[
        SizedBox(height: 8.r),
        BigButton(label: 'Log by scan', icon: Icons.qr_code_scanner, style: BigButtonStyle.tonal, height: 44.r, onPressed: widget.onScan),
      ],
    ];

    final machine = [
      const FieldLabel('Machine total (never reset)'),
      TextField(
        controller: _total,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: mono(24, weight: FontWeight.w700),
        decoration: InputDecoration(hintText: prev == null ? 'e.g. 1482900' : 'after ${fmt(prev)}'),
      ),
      _check(),
      if (showReset)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _reset,
          onChanged: (v) => setState(() => _reset = v ?? false),
          title: Text('The machine total was reset', style: sans(14)),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
            child: Text(e.log == null ? 'New log' : 'Edit log', style: sans(21, weight: FontWeight.w700)),
          ),
          if (e.log != null) const Pill('LOGGED', kind: PillKind.success),
          IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close), tooltip: 'Close'),
        ]),
        SizedBox(height: 8.r),
        DateRow(label: 'Production day', date: date, onTap: _pickDate),
        SizedBox(height: 10.r),
        ProductTile(
          product: _product,
          onTap: () async {
            final p = await showProductDialog(context, current: _product, products: widget.products);
            if (p != null) setState(() => _product = p.trim());
          },
        ),
        SizedBox(height: 16.r),
        ...printed,
        SizedBox(height: 16.r),
        ...machine,
        SizedBox(height: 16.r),
        const FieldLabel('Note (optional)'),
        TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(hintText: 'e.g. Line maintenance at 14:00')),
        SizedBox(height: 12.r),
        Container(
          padding: EdgeInsets.fromLTRB(12.r, 4.r, 4.r, 4.r),
          decoration: BoxDecoration(color: C.low, borderRadius: BorderRadius.circular(12.r)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text(
                  e.off
                      ? '${e.holiday ?? 'Day off'} — no target'
                      : _ownTarget
                          ? 'Own target for this day'
                          : 'Target ${fmt(e.monthTarget)} (month daily target)',
                  style: sans(14, weight: FontWeight.w600),
                ),
              ),
              if (!e.off)
                TextButton(
                  onPressed: () => setState(() {
                    _ownTarget = !_ownTarget;
                    if (_ownTarget && _target.text.isEmpty) _target.text = e.monthTarget?.toString() ?? '';
                  }),
                  child: Text(_ownTarget ? 'USE MONTH TARGET' : 'CHANGE FOR THIS DAY', style: mono(11, weight: FontWeight.w700, color: C.primary)),
                ),
            ]),
            if (_ownTarget && !e.off)
              Padding(
                padding: EdgeInsets.only(right: 8.r, bottom: 8.r),
                child: TextField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: mono(18, weight: FontWeight.w700, color: C.success),
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.only(right: 8.r),
              value: e.off,
              onChanged: widget.onOffChanged,
              title: Text('Day off', style: sans(14)),
              subtitle: Text('Not a working day: no target, not counted as missing', style: sans(12, color: C.onVariant)),
            ),
          ]),
        ),
        SizedBox(height: 16.r),
        BigButton(label: e.log == null ? 'Save log' : 'Save changes', icon: Icons.check_circle_outline, onPressed: _saving ? null : _save),
        if (e.log != null) ...[
          SizedBox(height: 4.r),
          TextButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    if (await confirm(context, 'Delete this log?', fmtDay(e.date), 'Delete')) await widget.onDelete();
                  },
            icon: const Icon(Icons.delete_outline, color: C.danger),
            label: Text('DELETE LOG', style: mono(12, weight: FontWeight.w700, color: C.danger)),
          ),
        ],
      ],
    );
  }
}
