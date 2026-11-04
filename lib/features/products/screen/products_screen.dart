import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/product_stats.dart';
import '../../../core/data/tracker_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/adaptive_layout.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/history_header.dart';
import '../../../core/widgets/product_field.dart';
import '../cubit/products_cubit.dart';
import '../widget/product_row.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(create: (context) => ProductsCubit(context.read<TrackerRepository>()), child: const _ProductsView());
}

class _ProductsView extends StatelessWidget {
  const _ProductsView();

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<ProductsCubit>();
    final name = await showProductDialog(context, current: '', products: const [], title: 'New product');
    if (name != null) await cubit.add(name);
  }

  Future<void> _rename(BuildContext context, ProductStats product) async {
    final cubit = context.read<ProductsCubit>();
    final others = [for (final p in cubit.state) if (p.name != product.name) p.name];
    final name = await showProductDialog(context, current: product.name, products: others, title: 'Rename product');
    if (name != null && name.trim().isNotEmpty) await cubit.rename(product.name, name);
  }

  Future<void> _delete(BuildContext context, ProductStats product) async {
    final cubit = context.read<ProductsCubit>();
    if (await confirm(context, 'Delete this product?', product.name, 'Delete')) await cubit.delete(product.name);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const TrackerAppBar('Products'),
        body: BlocBuilder<ProductsCubit, List<ProductStats>>(
          builder: (context, products) => TwoPane(
            stackGap: 24.r,
            left: [
              BigButton(label: 'Add product', icon: Icons.add, onPressed: () => _add(context)),
              SizedBox(height: 12.r),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 18.r, color: C.onVariant),
                SizedBox(width: 8.r),
                Expanded(
                  child: Text(
                    'Pick a product when you add a QR file. Daily logs take the product of the active list. Renaming to an existing product merges the two.',
                    style: sans(13, color: C.onVariant),
                  ),
                ),
              ]),
            ],
            right: [
              HistoryHeader(count: products.length, title: 'Products'),
              SizedBox(height: 12.r),
              if (products.isEmpty) Panel(child: Text('No products yet.', style: sans(15, color: C.onVariant))),
              for (final product in products)
                ProductRow(stats: product, onRename: () => _rename(context, product), onDelete: () => _delete(context, product)),
              SizedBox(height: 8.r),
            ],
          ),
        ),
      );
}
