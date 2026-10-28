import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/tracker_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/adaptive_layout.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/history_header.dart';
import '../cubit/shipping_cubit.dart';
import '../model/shipping_state.dart';
import '../widget/period_compare_card.dart';
import '../widget/ship_form.dart';
import '../widget/ship_history_row.dart';
import '../widget/start_balance_card.dart';
import '../widget/store_balance_card.dart';

class ShippingScreen extends StatelessWidget {
  const ShippingScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => ShippingCubit(context.read<TrackerRepository>()),
        child: const _ShippingView(),
      );
}

class _ShippingView extends StatelessWidget {
  const _ShippingView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShippingCubit>();

    return Scaffold(
      appBar: const TrackerAppBar('Shipped'),
      body: BlocBuilder<ShippingCubit, ShippingState>(
        // tablet: balance and entry form on the left, period comparison and history on the right
        builder: (context, state) => TwoPane(
          stackGap: 8.r,
          left: [
            StoreBalanceCard(stats: state.stats),
            ShipForm(
              date: state.date,
              shipped: state.shipped,
              formVersion: state.formVersion,
              editing: state.editing?.date,
              onNewEntry: cubit.newEntry,
              onPickDate: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: state.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (d != null) cubit.setDate(d);
              },
              onSave: (qty) async {
                final editing = state.editing;
                final error = await cubit.save(qty);
                if (context.mounted) {
                  showSnack(context, error ?? (editing == null ? 'Shipment saved' : '${fmtDay(editing.date)} updated'), error: error != null);
                }
                return error == null;
              },
            ),
            StartBalanceCard(qty: state.stats.startQty, date: state.stats.startDate, onChanged: cubit.setStartBalance),
          ],
          right: [
            PeriodCompareCard(period: state.period, preset: state.preset, onPreset: cubit.selectPreset, onRange: cubit.selectRange),
            HistoryHeader(count: state.history.length, title: 'Shipments'),
            SizedBox(height: 12.r),
            if (state.history.isEmpty) Panel(child: Text('No shipments logged yet.', style: sans(15, color: C.onVariant))),
            for (final day in state.history)
              ShipHistoryRow(
                day: day,
                selected: state.editing?.id == day.id,
                onTap: () => cubit.editDay(day),
                confirmDelete: () => confirm(context, 'Delete this shipment?', fmtDay(day.date), 'Delete'),
                onDelete: () => cubit.delete(day.id),
              ),
          ],
        ),
      ),
    );
  }
}
