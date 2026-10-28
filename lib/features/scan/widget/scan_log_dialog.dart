import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/stepper_field.dart';
import '../../../core/data/scan_log.dart';

/// What the user chose in the Log by scan popup.
sealed class ScanLogChoice {
  const ScanLogChoice();
}

/// Save the log with this counter (for the production day picked in the popup).
class ScanLogConfirm extends ScanLogChoice {
  const ScanLogConfirm(this.draft, this.counter);

  final ScanLogDraft draft;
  final int counter;
}

/// Open the scanner again.
class ScanLogRescan extends ScanLogChoice {
  const ScanLogRescan();
}

/// Shows the counter worked out from the scan; the user can change the production day ([draftFor] works the
/// counter out again) and edit the counter, then confirm or cancel. Resolves to null when cancelled.
Future<ScanLogChoice?> showScanLogDialog(BuildContext context, ScanLogDraft draft, {required ScanLogDraft Function(DateTime date) draftFor}) =>
    showDialog<ScanLogChoice>(context: context, barrierDismissible: false, builder: (_) => _ScanLogDialog(draft, draftFor));

class _ScanLogDialog extends StatefulWidget {
  const _ScanLogDialog(this.draft, this.draftFor);

  final ScanLogDraft draft;
  final ScanLogDraft Function(DateTime date) draftFor;

  @override
  State<_ScanLogDialog> createState() => _ScanLogDialogState();
}

class _ScanLogDialogState extends State<_ScanLogDialog> {
  late ScanLogDraft _draft = widget.draft;
  late final _counter = TextEditingController(text: _draft.counter?.toString() ?? '');

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _draft.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Production day',
    );
    if (d == null || !mounted) return;
    setState(() {
      _draft = widget.draftFor(d);
      _counter.text = _draft.counter?.toString() ?? '';
    });
  }

  @override
  void initState() {
    super.initState();
    _counter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _counter.dispose();
    super.dispose();
  }

  Widget _line(String label, String value, {Color? color}) => Padding(
        padding: EdgeInsets.only(bottom: 6.r),
        child: Row(children: [
          Expanded(child: Text(label, style: sans(14, color: C.onVariant))),
          Text(value, style: mono(14, weight: FontWeight.w700, color: color ?? C.onSurface)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    final value = int.tryParse(_counter.text);
    final cancel = TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL'));
    final rescan = TextButton(onPressed: () => Navigator.pop(context, const ScanLogRescan()), child: const Text('SCAN AGAIN'));

    if (!d.inList) {
      return AlertDialog(
        icon: Icon(Icons.qr_code_2, color: C.danger, size: 32.r),
        title: Text('Code not in your list', style: sans(20, weight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.code, style: mono(14, weight: FontWeight.w600)),
          SizedBox(height: 8.r),
          Text('The counter can only be worked out from a code in the imported list. Scan the code the machine is printing now.',
              style: sans(14, color: C.onVariant)),
        ]),
        actions: [cancel, rescan],
      );
    }

    final baseline = d.baseline;
    return AlertDialog(
      icon: Icon(Icons.qr_code_scanner, color: C.primary, size: 32.r),
      title: Text('Log by scan', style: sans(20, weight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Material(
            color: C.high,
            borderRadius: BorderRadius.circular(8.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(8.r),
              onTap: _pickDate,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 10.r),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 18.r, color: C.onVariant),
                  SizedBox(width: 10.r),
                  Expanded(child: Text('Production day', style: sans(14, color: C.onVariant))),
                  Text(fmtDate(d.date), style: sans(15, weight: FontWeight.w700)),
                  Icon(Icons.chevron_right, size: 20.r, color: C.onVariant),
                ]),
              ),
            ),
          ),
          SizedBox(height: 12.r),
          _line('Scanned now', '#${fmt(d.pos)}', color: C.primary),
          _line(
            switch (baseline.source) {
              BaselineSource.log => 'Last scan log (${fmtDate(baseline.at!)})',
              BaselineSource.scan => 'Last scan before (${fmtTime(baseline.at!.millisecondsSinceEpoch)})',
              BaselineSource.listStart => 'Start of the list',
            },
            '#${fmt(baseline.pos)}',
          ),
          if (d.loggedCounter != null)
            _line(
              d.loggedPos == null ? 'Already logged this day' : 'Already logged (last scan #${fmt(d.loggedPos)})',
              fmt(d.loggedCounter),
              color: d.behindDay || d.lowersLogged ? C.warning : null,
            ),
          SizedBox(height: 10.r),
          const MicroLabel('Counter (codes printed)'),
          SizedBox(height: 8.r),
          StepperField(controller: _counter, color: C.primary),
          SizedBox(height: 10.r),
          Text(
            switch (d) {
              _ when d.behindDay =>
                'This code is behind the last scan for this day (#${fmt(d.loggedPos)}), so the logged ${fmt(d.loggedCounter)} is kept. Change it only if it is wrong.',
              _ when d.behindStart => 'This code is behind the last scan log. Check you scanned the code being printed now, or enter the counter.',
              _ when d.lowersLogged =>
                'This is lower than the ${fmt(d.loggedCounter)} already logged for this day. Confirming replaces it. Check before you confirm.',
              _ when baseline.source == BaselineSource.listStart =>
                'Nothing scanned before this day, so it counts from the start of the list. Change it if printing started earlier.',
              _ => 'Codes printed since the last scan. Change it if the machine counter says otherwise.',
            },
            style: sans(13, color: d.behind || d.lowersLogged ? C.warning : C.onVariant),
          ),
        ]),
      ),
      actions: [
        cancel,
        rescan,
        FilledButton(
          onPressed: value == null ? null : () => Navigator.pop(context, ScanLogConfirm(d, value)),
          child: const Text('CONFIRM'),
        ),
      ],
    );
  }
}
