import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Starting balance: printed lids already in store, counted today. Edited in a dialog.
class StartBalanceCard extends StatelessWidget {
  const StartBalanceCard({super.key, required this.qty, required this.date, required this.onChanged});

  final int? qty;

  /// yyyy-MM-dd, empty when not set.
  final String date;

  /// Null clears the starting balance.
  final ValueChanged<int?> onChanged;

  Future<void> _edit(BuildContext context) async {
    final text = TextEditingController(text: qty?.toString() ?? '');
    final result = await showDialog<(int?,)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Printed lids in store', style: sans(20, weight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Count the printed lids in store now (before today’s printing and shipping).', style: sans(14, color: C.onVariant)),
          SizedBox(height: 12.r),
          TextField(
            controller: text,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: mono(20, weight: FontWeight.w700),
            decoration: const InputDecoration(hintText: 'Lids counted'),
          ),
        ]),
        actions: [
          if (qty != null) TextButton(onPressed: () => Navigator.pop(context, (null,)), child: const Text('CLEAR')),
          FilledButton(onPressed: () => Navigator.pop(context, (int.tryParse(text.text),)), child: const Text('SAVE')),
        ],
      ),
    );
    text.dispose();
    if (result != null) onChanged(result.$1);
  }

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: () => _edit(context),
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Row(children: [
                IconTile(Icons.fact_check_outlined, iconColor: qty == null ? C.onVariant : C.primary),
                SizedBox(width: 14.r),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Starting balance', style: sans(18, weight: FontWeight.w600)),
                      Text(
                        qty == null ? 'Not set — tap to enter the printed lids in store now' : '${fmt(qty)} lids counted on ${fmtDay(date)}',
                        style: sans(14, color: C.onVariant),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: C.onVariant),
              ]),
            ),
          ),
        ),
      );
}
