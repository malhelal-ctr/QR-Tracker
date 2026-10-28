import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/repository_listener.dart';
import '../../../core/data/tracker_repository.dart';
import '../../../core/utils/period.dart';
import '../model/dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> with RepositoryListener {
  DashboardCubit(this._repository) : super(_build(_repository, PeriodPreset.last7Days, null)) {
    listenTo(_repository, () => emit(_build(_repository, state.preset, _custom)));
  }

  final TrackerRepository _repository;

  /// The picked range while the preset is [PeriodPreset.custom].
  (DateTime, DateTime)? _custom;

  static DashboardState _build(TrackerRepository repository, PeriodPreset preset, (DateTime, DateTime)? custom) {
    final (from, to) = preset == PeriodPreset.custom && custom != null ? custom : presetRange(preset, days: repository.days.values);
    return DashboardState.from(repository, preset: preset, from: from, to: to);
  }

  void selectPreset(PeriodPreset preset) => emit(_build(_repository, preset, _custom));

  /// A range picked in the date-range picker.
  void selectRange(DateTime from, DateTime to) {
    _custom = (from, to);
    emit(_build(_repository, PeriodPreset.custom, _custom));
  }
}
