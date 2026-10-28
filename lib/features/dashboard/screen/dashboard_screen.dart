import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/tracker_repository.dart';
import '../../../core/widgets/adaptive_layout.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../main/cubit/main_cubit.dart';
import '../cubit/dashboard_cubit.dart';
import '../model/dashboard_state.dart';
import '../widget/empty_list_card.dart';
import '../widget/plan_card.dart';
import '../widget/position_card.dart';
import '../widget/stock_card.dart';
import '../widget/summary_card.dart';
import '../widget/today_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => DashboardCubit(context.read<TrackerRepository>()),
        child: const _DashboardView(),
      );
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    void go(AppTab tab) => context.read<MainCubit>().select(tab);

    return Scaffold(
      appBar: const TrackerAppBar('Dashboard'),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        // tablet: print position and period summary on the left, today, stock and plan on the right
        builder: (context, state) => TwoPane(
          left: [
            if (state.hasCodes)
              PositionCard(stats: state.stats, fileName: state.fileName, onScan: () => go(AppTab.scan))
            else
              EmptyListCard(onImport: () => go(AppTab.data)),
            SummaryCard(
              summary: state.summary,
              preset: state.preset,
              onPreset: context.read<DashboardCubit>().selectPreset,
              onRange: context.read<DashboardCubit>().selectRange,
            ),
          ],
          right: [
            TodayCard(stats: state.stats, goalMet: state.goalMet, onLog: () => go(AppTab.dailyLog)),
            StockCard(stock: state.stock, onOpen: () => go(AppTab.stock)),
            if (state.hasCodes) PlanCard(stats: state.stats, onPace: state.onPace),
          ],
        ),
      ),
    );
  }
}
