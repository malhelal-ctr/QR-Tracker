import 'package:flutter_bloc/flutter_bloc.dart';

enum AppTab { dashboard, scan, dailyLog, shipping, stock, data }

/// Selected bottom-navigation tab.
class MainCubit extends Cubit<AppTab> {
  MainCubit() : super(AppTab.dashboard);

  void select(AppTab tab) => emit(tab);
}
