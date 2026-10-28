import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../daily_log/screen/daily_log_screen.dart';
import '../../dashboard/screen/dashboard_screen.dart';
import '../../data/screen/data_screen.dart';
import '../../scan/screen/scan_screen.dart';
import '../../shipping/screen/shipping_screen.dart';
import '../../stock/screen/stock_screen.dart';
import '../cubit/main_cubit.dart';

// short labels so six tabs fit on a phone
const _tabs = [
  (icon: Icons.speed_outlined, selected: Icons.speed, label: 'HOME'),
  (icon: Icons.qr_code_scanner, selected: Icons.qr_code_scanner, label: 'SCAN'),
  (icon: Icons.event_note_outlined, selected: Icons.event_note, label: 'LOG'),
  (icon: Icons.local_shipping_outlined, selected: Icons.local_shipping, label: 'SHIPPED'),
  (icon: Icons.inventory_2_outlined, selected: Icons.inventory_2, label: 'STOCK'),
  (icon: Icons.storage_outlined, selected: Icons.storage, label: 'DATA'),
];

/// Navigation shell: bottom bar on phones, side rail on tablets.
/// Screens are rebuilt on tab change so the camera only runs on the Scan tab.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => MainCubit(),
        child: BlocBuilder<MainCubit, AppTab>(
          builder: (context, tab) {
            // depend on the screen size so phone/tablet mode follows rotation, folding and split-screen
            MediaQuery.sizeOf(context);
            final screen = switch (tab) {
              AppTab.dashboard => const DashboardScreen(),
              AppTab.scan => const ScanScreen(),
              AppTab.dailyLog => const DailyLogScreen(),
              AppTab.shipping => const ShippingScreen(),
              AppTab.stock => const StockScreen(),
              AppTab.data => const DataScreen(),
            };
            void select(int i) => context.read<MainCubit>().select(AppTab.values[i]);

            if (isTablet) {
              return Scaffold(
                body: Row(children: [
                  NavigationRail(
                    selectedIndex: tab.index,
                    onDestinationSelected: select,
                    backgroundColor: C.lowest,
                    indicatorColor: C.high,
                    indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    minWidth: 96.r,
                    labelType: NavigationRailLabelType.all,
                    groupAlignment: -0.85,
                    selectedIconTheme: IconThemeData(color: C.primary, size: 28.r),
                    unselectedIconTheme: IconThemeData(color: C.onVariant, size: 28.r),
                    selectedLabelTextStyle: mono(11, weight: FontWeight.w700, spacing: 0.8, color: C.primary),
                    unselectedLabelTextStyle: mono(11, weight: FontWeight.w700, spacing: 0.8, color: C.onVariant),
                    destinations: [
                      for (final t in _tabs)
                        NavigationRailDestination(
                          icon: Icon(t.icon),
                          selectedIcon: Icon(t.selected),
                          label: Text(t.label),
                          padding: EdgeInsets.symmetric(vertical: 6.r),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1, color: C.low),
                  Expanded(child: screen),
                ]),
              );
            }

            return Scaffold(
              body: screen,
              bottomNavigationBar: NavigationBar(
                selectedIndex: tab.index,
                onDestinationSelected: select,
                destinations: [
                  for (final t in _tabs)
                    NavigationDestination(icon: Icon(t.icon, size: 24.r), selectedIcon: Icon(t.selected, size: 24.r), label: t.label),
                ],
              ),
            );
          },
        ),
      );
}
