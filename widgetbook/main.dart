import 'package:flutter/material.dart';
import 'package:qr_tracker/core/theme/app_theme.dart';
import 'package:qr_tracker/core/utils/responsive.dart';
import 'package:sizer/sizer.dart' show Sizer;
import 'package:widgetbook/widgetbook.dart';

import 'core_use_cases.dart';
import 'feature_use_cases.dart';

// Run with: flutter run -t widgetbook/main.dart -d chrome
void main() => runApp(const QrTrackerWidgetbook());

class QrTrackerWidgetbook extends StatelessWidget {
  const QrTrackerWidgetbook({super.key});

  @override
  Widget build(BuildContext context) => Widgetbook.material(
        directories: [
          WidgetbookCategory(name: 'Core', children: coreUseCases),
          WidgetbookCategory(name: 'Features', children: featureUseCases),
        ],
        addons: [
          ViewportAddon([
            AndroidViewports.samsungGalaxyS20,
            AndroidViewports.samsungGalaxyA50,
            AndroidViewports.mediumTablet,
            Viewports.none,
          ]),
          TextScaleAddon(min: 1, max: 2),
          InspectorAddon(),
          // Sizer goes inside the viewport so `.r` scales to the chosen device; the theme is
          // built here (not in a theme addon) because buildTheme() needs Sizer to have run.
          BuilderAddon(
            name: 'App frame',
            builder: (context, child) => Sizer(
              builder: (context, orientation, screenType) => Theme(
                data: buildTheme(),
                child: Scaffold(
                  backgroundColor: C.surface,
                  body: SingleChildScrollView(padding: EdgeInsets.all(16.r), child: child),
                ),
              ),
            ),
          ),
        ],
      );
}
