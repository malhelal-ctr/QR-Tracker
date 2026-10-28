import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/date_row.dart';
import '../../../core/widgets/field_label.dart';
import '../../../core/widgets/stepper_field.dart';

/// Entry form for products shipped on a day; also used to edit a day from the history.
class ShipForm extends StatefulWidget {
  const ShipForm({
    super.key,
    required this.date,
    required this.shipped,
    required this.formVersion,
    required this.editing,
    required this.onPickDate,
    required this.onNewEntry,
    required this.onSave,
  });

  final DateTime date;

  /// Value to show; pushed into the field whenever [formVersion] changes.
  final int? shipped;
  final int formVersion;

  /// Day being edited (yyyy-MM-dd), or null for a new entry.
  final String? editing;
  final VoidCallback onPickDate;
  final VoidCallback onNewEntry;

  /// Returns true when saved.
  final Future<bool> Function(String quantity) onSave;

  @override
  State<ShipForm> createState() => _ShipFormState();
}

class _ShipFormState extends State<ShipForm> {
  late final _qty = TextEditingController(text: widget.shipped?.toString() ?? '');

  @override
  void didUpdateWidget(ShipForm old) {
    super.didUpdateWidget(old);
    if (old.formVersion != widget.formVersion) _qty.text = widget.shipped?.toString() ?? '';
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (await widget.onSave(_qty.text) && mounted) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            editing == null ? 'Log shipment' : 'Editing ${fmtDay(editing)}',
            icon: editing == null ? Icons.local_shipping_outlined : Icons.edit_outlined,
            trailing: editing == null
                ? null
                : TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: C.high,
                      foregroundColor: C.onSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onPressed: widget.onNewEntry,
                    icon: Icon(Icons.add, size: 18.r),
                    label: Text('NEW ENTRY', style: mono(12, weight: FontWeight.w700)),
                  ),
          ),
          DateRow(
            label: 'Shipping day',
            date: widget.date,
            iconColor: C.success,
            badge: ymd(widget.date) == ymd(DateTime.now()) ? 'TODAY' : null,
            onTap: widget.onPickDate,
          ),
          SizedBox(height: 16.r),
          const FieldLabel('Products shipped (lids used)'),
          StepperField(controller: _qty, color: C.success),
          if (editing != null) ...[
            SizedBox(height: 8.r),
            Text('Clear the number to remove this day’s shipment.', style: sans(13, color: C.onVariant)),
          ],
          SizedBox(height: 16.r),
          BigButton(
            label: editing == null ? 'Save shipment' : 'Save changes',
            icon: Icons.check_circle_outline,
            style: BigButtonStyle.success,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
