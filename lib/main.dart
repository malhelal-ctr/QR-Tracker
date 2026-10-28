import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sizer/sizer.dart';

import 'core/data/tracker_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/main/widget/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = TrackerRepository();
  await repository.init();
  runApp(QrTrackerApp(repository: repository));
}

class QrTrackerApp extends StatelessWidget {
  const QrTrackerApp({super.key, required this.repository});

  final TrackerRepository repository;

  @override
  Widget build(BuildContext context) => RepositoryProvider.value(
        value: repository,
        // Sizer measures the screen (phone / tablet, orientation) before anything is sized with `.r`.
        child: Sizer(
          builder: (context, orientation, screenType) => MaterialApp(
            title: 'QR Tracker',
            debugShowCheckedModeBanner: false,
            // dark industrial theme only: less glare under factory lighting
            theme: buildTheme(),
            home: const MainShell(),
          ),
        ),
      );
}
