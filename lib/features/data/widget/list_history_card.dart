import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import 'action_row.dart';

/// Finished QR lists, newest first.
class ListHistoryCard extends StatelessWidget {
  const ListHistoryCard({super.key, required this.lists, required this.onOpen});

  final List<ArchivedList> lists;
  final ValueChanged<ArchivedList> onOpen;

  @override
  Widget build(BuildContext context) => Panel(
        padding: lists.isEmpty ? null : EdgeInsets.symmetric(vertical: 4.r),
        child: lists.isEmpty
            ? Text('No archived lists yet.', style: sans(15, color: C.onVariant))
            : Column(children: [
                for (final (i, list) in lists.indexed) ...[
                  if (i > 0) Divider(indent: 16.r, endIndent: 16.r),
                  ActionRow(
                    icon: Icons.history,
                    title: list.fileName,
                    subtitle: '${fmt(list.total)} codes · ${fmt(list.scans.length)} scans · archived ${fmtTime(list.archivedAt)}',
                    onTap: () => onOpen(list),
                  ),
                ],
              ]),
      );
}
