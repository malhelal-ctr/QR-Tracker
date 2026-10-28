import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/date_row.dart';
import '../../../core/widgets/field_label.dart';
import '../../../core/widgets/stepper_field.dart';

/// Entry form: delivery received, waste, or a physical stock count.
class MovementForm extends StatefulWidget {
  const MovementForm({
    super.key,
    required this.type,
    required this.date,
    required this.onTypeChanged,
    required this.onPickDate,
    required this.onSave,
  });

  final StockMoveType type;
  final DateTime date;
  final ValueChanged<StockMoveType> onTypeChanged;
  final VoidCallback onPickDate;

  /// Returns true when saved, so the fields can be cleared.
  final Future<bool> Function(String quantity, String note) onSave;

  @override
  State<MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<MovementForm> {
  final _qty = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (await widget.onSave(_qty.text, _note.text)) {
      _qty.clear();
      _note.clear();
      if (mounted) FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final (field, button, style, color) = switch (widget.type) {
      StockMoveType.received => ('Lids received', 'Add delivery', BigButtonStyle.success, C.success),
      StockMoveType.waste => ('Lids wasted', 'Log waste', BigButtonStyle.danger, C.danger),
      StockMoveType.count => ('Lids counted on hand', 'Save stock count', BigButtonStyle.primary, C.primary),
    };

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Update stock', icon: Icons.edit_note),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<StockMoveType>(
              segments: [
                ButtonSegment(value: StockMoveType.received, icon: Icon(Icons.local_shipping_outlined, size: 18.r), label: const Text('Received')),
                ButtonSegment(value: StockMoveType.waste, icon: Icon(Icons.delete_outline, size: 18.r), label: const Text('Waste')),
                ButtonSegment(value: StockMoveType.count, icon: Icon(Icons.fact_check_outlined, size: 18.r), label: const Text('Count')),
              ],
              selected: {widget.type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => widget.onTypeChanged(s.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: C.lowest,
                selectedBackgroundColor: C.high,
                selectedForegroundColor: color,
                foregroundColor: C.onVariant,
                side: const BorderSide(color: C.outlineVariant),
                textStyle: sans(14, weight: FontWeight.w600),
                padding: EdgeInsets.symmetric(vertical: 12.r),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
          if (widget.type == StockMoveType.count) ...[
            SizedBox(height: 10.r),
            Text('A count replaces the stock level. Daily counters you log after it are subtracted.', style: sans(13, color: C.onVariant)),
          ],
          SizedBox(height: 14.r),
          DateRow(label: 'Date', date: widget.date, onTap: widget.onPickDate, iconColor: color),
          SizedBox(height: 16.r),
          FieldLabel(field),
          StepperField(controller: _qty, color: color, step: 1000),
          SizedBox(height: 16.r),
          const FieldLabel('Note (optional)'),
          TextField(controller: _note, decoration: const InputDecoration(hintText: 'e.g. Supplier, batch no., reason')),
          SizedBox(height: 16.r),
          BigButton(label: button, icon: Icons.check_circle_outline, style: style, onPressed: _save),
        ],
      ),
    );
  }
}
