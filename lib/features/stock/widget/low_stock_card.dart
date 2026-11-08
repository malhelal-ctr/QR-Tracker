import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Low-stock alert settings: lead time (working days to get new lids), the phone notification and its
/// time, and an optional minimum number of lids.
class LowStockCard extends StatelessWidget {
  const LowStockCard({
    super.key,
    required this.leadTime,
    required this.notify,
    required this.notifyAt,
    required this.lowStock,
    required this.onLeadTime,
    required this.onNotify,
    required this.onLowStock,
  });

  final int leadTime;
  final bool notify;

  /// Minutes after midnight.
  final int notifyAt;
  final int? lowStock;
  final ValueChanged<int> onLeadTime;
  final void Function(bool on, int? minutes) onNotify;

  /// Null turns the minimum off.
  final ValueChanged<int?> onLowStock;

  Future<void> _editMinimum(BuildContext context) async {
    final text = TextEditingController(text: lowStock?.toString() ?? '');
    final result = await showDialog<(int?,)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Minimum lids', style: sans(20, weight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Also warn when the lids on hand go below this number, whatever the run-out day.', style: sans(14, color: C.onVariant)),
          SizedBox(height: 12.r),
          TextField(
            controller: text,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: mono(20, weight: FontWeight.w700),
            decoration: const InputDecoration(hintText: 'Warn at or below… lids'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, (null,)), child: const Text('TURN OFF')),
          FilledButton(onPressed: () => Navigator.pop(context, (int.tryParse(text.text),)), child: const Text('SAVE')),
        ],
      ),
    );
    text.dispose();
    if (result != null) onLowStock(result.$1);
  }

  Future<void> _pickTime(BuildContext context) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: notifyAt ~/ 60, minute: notifyAt % 60));
    if (t != null) onNotify(true, t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: notifyAt ~/ 60, minute: notifyAt % 60).format(context);

    Widget row({required IconData icon, required String title, required String subtitle, Widget? trailing, VoidCallback? onTap, Color? iconColor}) => InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.r),
            child: Row(children: [
              IconTile(icon, size: 40.r, iconColor: iconColor ?? C.primary),
              SizedBox(width: 12.r),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: sans(16, weight: FontWeight.w600)),
                  Text(subtitle, style: sans(13, color: C.onVariant)),
                ]),
              ),
              ?trailing,
            ]),
          ),
        );

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Low stock alert', icon: Icons.notifications_active_outlined),
        Text('Stock is low when the lids run out within the lead time, at your average printing.', style: sans(13, color: C.onVariant)),
        SizedBox(height: 4.r),
        row(
          icon: Icons.local_shipping_outlined,
          title: 'Lead time',
          subtitle: 'Working days to get new lids after ordering',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: leadTime > 1 ? () => onLeadTime(leadTime - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
            Text('$leadTime', style: mono(20, weight: FontWeight.w700)),
            IconButton(onPressed: () => onLeadTime(leadTime + 1), icon: const Icon(Icons.add_circle_outline)),
          ]),
        ),
        row(
          icon: Icons.notifications_outlined,
          title: 'Phone notification',
          subtitle: notify ? 'Working days at $time while stock is low · tap to change the time' : 'Off',
          iconColor: notify ? C.warning : C.onVariant,
          onTap: notify ? () => _pickTime(context) : null,
          trailing: Switch(value: notify, onChanged: (v) => onNotify(v, null)),
        ),
        row(
          icon: Icons.inventory_outlined,
          title: 'Minimum lids',
          subtitle: lowStock == null ? 'Off · tap to also warn below a number of lids' : 'Also warn at or below ${fmt(lowStock)} lids',
          iconColor: lowStock == null ? C.onVariant : C.warning,
          onTap: () => _editMinimum(context),
          trailing: const Icon(Icons.chevron_right, color: C.onVariant),
        ),
      ]),
    );
  }
}
