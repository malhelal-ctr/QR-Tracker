import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/tracker_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/adaptive_layout.dart';
import '../../../core/widgets/app_widgets.dart';
import '../cubit/data_cubit.dart';
import '../model/data_state.dart';
import '../widget/action_row.dart';
import '../widget/danger_zone_card.dart';
import '../widget/export_backup_card.dart';
import '../widget/import_sheet.dart';
import '../widget/period_card.dart';
import '../widget/qr_list_card.dart';

class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => DataCubit(context.read<TrackerRepository>()),
        child: const _DataView(),
      );
}

class _DataView extends StatelessWidget {
  const _DataView();

  /// Runs [task], showing a snack with its message (if any) or the error.
  Future<void> _run(BuildContext context, Future<String?> Function() task) async {
    try {
      final message = await task();
      if (message != null && context.mounted) showSnack(context, message);
    } catch (e) {
      if (context.mounted) showSnack(context, e is FormatException ? e.message : '$e', error: true);
    }
  }

  Future<void> _import(BuildContext context) => _run(context, () async {
        final cubit = context.read<DataCubit>();
        final preview = await cubit.pickImportFile();
        if (preview == null || !context.mounted) return null;
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          constraints: BoxConstraints(maxWidth: 640.r),
          builder: (_) => ImportSheet(
            preview: preview,
            hasExistingList: cubit.state.hasList,
            onImport: (p) async {
              final count = await cubit.importCodes(p);
              if (context.mounted) showSnack(context, 'Imported ${fmt(count)} codes');
            },
          ),
        );
        return null;
      });

  Future<void> _pickPeriodEnd(BuildContext context, DataState state) async {
    final cubit = context.read<DataCubit>();
    final d = await showDatePicker(
      context: context,
      initialDate: state.periodEnd.isEmpty ? DateTime.now() : DateTime.parse(state.periodEnd),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d != null) await cubit.setPeriodEnd(d);
  }

  Future<void> _restore(BuildContext context) => _run(context, () async {
        final cubit = context.read<DataCubit>();
        final json = await cubit.pickBackup();
        if (json == null || !context.mounted) return null;
        if (!await confirm(context, 'Restore backup?', 'This replaces everything on this phone with the backup.', 'Restore')) return null;
        await cubit.restore(json);
        return 'Backup restored';
      });

  Future<void> _erase(BuildContext context) async {
    final cubit = context.read<DataCubit>();
    if (await confirm(context, 'Erase all data?', 'QR list, daily log, scans and lid stock will be deleted from this phone. Make a backup first.', 'Erase')) {
      await cubit.eraseAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DataCubit>();
    String? saved(String? name) => name == null ? null : 'Saved $name';

    return Scaffold(
      appBar: const TrackerAppBar('Data'),
      body: BlocBuilder<DataCubit, DataState>(
        // tablet: list and period on the left, export and danger zone on the right
        builder: (context, state) => TwoPane(
          left: [
            SectionTitle('QR list', icon: Icons.qr_code_2, upper: true, trailing: MicroLabel('${fmt(state.scanCount)} scans')),
            QrListCard(state: state),
            ActionRow(
              icon: Icons.cloud_upload_outlined,
              iconBg: C.primaryContainer,
              iconColor: Colors.white,
              title: state.hasList ? 'Replace with new file' : 'Import CSV / Excel',
              subtitle: '.csv, .txt or .xlsx — one column, in print order',
              busy: state.busy,
              onTap: state.busy ? null : () => _import(context),
              standalone: true,
            ),
            SizedBox(height: 8.r),
            const SectionTitle('Period', icon: Icons.calendar_month_outlined, upper: true),
            PeriodCard(state: state, onPick: () => _pickPeriodEnd(context, state), onClear: () => cubit.setPeriodEnd(null)),
          ],
          right: [
            const SectionTitle('Export & backup', icon: Icons.inventory_2_outlined, upper: true),
            ExportBackupCard(
              onExportLog: () => _run(context, () async => saved(await cubit.exportDailyLog())),
              onExportScans: () => _run(context, () async => saved(await cubit.exportScans())),
              onExportStock: () => _run(context, () async => saved(await cubit.exportStock())),
              onBackup: () => _run(context, () async => saved(await cubit.backup())),
              onRestore: () => _restore(context),
            ),
            const SectionTitle('Danger zone', icon: Icons.warning_amber_rounded, upper: true, color: C.danger, trailing: MicroLabel('Irreversible', color: C.danger)),
            DangerZoneCard(onErase: () => _erase(context)),
          ],
        ),
      ),
    );
  }
}
