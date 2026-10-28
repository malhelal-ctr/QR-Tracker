import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Low-stock alert threshold, edited in a dialog.
class LowStockCard extends StatelessWidget {
  const LowStockCard({super.key, required this.lowStock, required this.onChanged});

  final int? lowStock;

  /// Null turns the alert off.
  final ValueChanged<int?> onChanged;

  Future<void> _edit(BuildContext context) async {
    final text = TextEditingController(text: lowStock?.toString() ?? '');
    final result = await showDialog<(int?,)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Low stock alert', style: sans(20, weight: FontWeight.w700)),
        content: TextField(
          controller: text,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: mono(20, weight: FontWeight.w700),
          decoration: const InputDecoration(hintText: 'Warn at or below… lids'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, (null,)), child: const Text('TURN OFF')),
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
                IconTile(Icons.notifications_active_outlined, iconColor: lowStock == null ? C.onVariant : C.warning),
                SizedBox(width: 14.r),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Low stock alert', style: sans(18, weight: FontWeight.w600)),
                      Text(lowStock == null ? 'Off — tap to set a minimum' : 'Warn at or below ${fmt(lowStock)} lids', style: sans(14, color: C.onVariant)),
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
