import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/tracker_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/adaptive_layout.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/history_header.dart';
import '../cubit/stock_cubit.dart';
import '../model/stock_state.dart';
import '../widget/low_stock_card.dart';
import '../widget/movement_form.dart';
import '../widget/stock_history_row.dart';
import '../widget/stock_level_card.dart';

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => StockCubit(context.read<TrackerRepository>()),
        child: const _StockView(),
      );
}

class _StockView extends StatelessWidget {
  const _StockView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StockCubit>();

    return Scaffold(
      appBar: const TrackerAppBar('Lid stock'),
      body: BlocBuilder<StockCubit, StockState>(
        // tablet: level and entry form on the left, stock log on the right
        builder: (context, state) => TwoPane(
          stackGap: 24.r,
          left: [
            StockLevelCard(stats: state.stats),
            MovementForm(
              type: state.type,
              date: state.date,
              onTypeChanged: cubit.setType,
              onPickDate: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: state.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) cubit.setDate(d);
              },
              onSave: (qty, note) async {
                final error = await cubit.add(qty, note);
                if (context.mounted) showSnack(context, error ?? 'Stock updated', error: error != null);
                return error == null;
              },
            ),
            LowStockCard(lowStock: state.stats.lowStock, onChanged: cubit.setLowStock),
          ],
          right: [
            HistoryHeader(count: state.history.length, title: 'Stock log'),
            SizedBox(height: 12.r),
            if (state.history.isEmpty)
              Panel(child: Text('No stock entries yet. Start with a stock count or a delivery.', style: sans(15, color: C.onVariant))),
            for (final move in state.history)
              StockHistoryRow(
                move: move,
                confirmDelete: () => confirm(context, 'Delete this entry?', fmtDay(move.date), 'Delete'),
                onDelete: () => cubit.delete(move.ts),
              ),
          ],
        ),
      ),
    );
  }
}
