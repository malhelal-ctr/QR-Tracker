import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'tracker_repository.dart';

/// Re-runs [onChange] whenever the repository data changes, and stops when the cubit closes.
mixin RepositoryListener<S> on Cubit<S> {
  StreamSubscription<void>? _subscription;

  void listenTo(TrackerRepository repository, void Function() onChange) {
    _subscription = repository.changes.listen((_) {
      if (!isClosed) onChange();
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
