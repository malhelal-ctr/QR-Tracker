import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/product_stats.dart';
import '../../../core/data/repository_listener.dart';
import '../../../core/data/tracker_repository.dart';

class ProductsCubit extends Cubit<List<ProductStats>> with RepositoryListener {
  ProductsCubit(this._repository) : super(_repository.productStats) {
    listenTo(_repository, () => emit(_repository.productStats));
  }

  final TrackerRepository _repository;

  Future<void> add(String name) => _repository.addProduct(name);

  Future<void> rename(String old, String name) => _repository.renameProduct(old, name);

  Future<void> delete(String name) => _repository.deleteProduct(name);
}
