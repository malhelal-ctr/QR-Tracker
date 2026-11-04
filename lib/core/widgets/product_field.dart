import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_widgets.dart';
import 'field_label.dart';

/// Product name box with the saved products as chips, so one product keeps one spelling.
class ProductField extends StatefulWidget {
  const ProductField({super.key, required this.products, required this.onChanged, this.initial = '', this.label = 'Product'});

  final List<String> products;
  final ValueChanged<String> onChanged;
  final String initial;
  final String label;

  @override
  State<ProductField> createState() => _ProductFieldState();
}

class _ProductFieldState extends State<ProductField> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    widget.onChanged(value);
  }

  void _pick(String product) {
    _name.text = product;
    _changed(product);
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(widget.label),
          if (widget.products.isNotEmpty) ...[
            Wrap(
              spacing: 8.r,
              runSpacing: 4.r,
              children: [
                for (final p in widget.products)
                  ChoiceChip(
                    label: Text(p, style: sans(14)),
                    selected: p.toLowerCase() == _name.text.trim().toLowerCase(),
                    selectedColor: C.primaryContainer,
                    onSelected: (_) => _pick(p),
                  ),
              ],
            ),
            SizedBox(height: 8.r),
          ],
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: _changed,
            decoration: InputDecoration(hintText: widget.products.isEmpty ? 'e.g. Cover Coat' : 'Or type a new product'),
          ),
        ],
      );
}

/// Asks for a product name. Null if cancelled; empty when the name was cleared.
Future<String?> showProductDialog(BuildContext context, {required String current, required List<String> products, String title = 'Which product?'}) {
  var value = current;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: sans(20, weight: FontWeight.w700)),
      content: SingleChildScrollView(child: ProductField(initial: current, products: products, onChanged: (v) => value = v)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(onPressed: () => Navigator.pop(context, value), child: const Text('SAVE')),
      ],
    ),
  );
}

/// Tappable row showing a record's product.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.onTap});

  final String product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Tile(
          child: Row(children: [
            Icon(Icons.sell_outlined, size: 18.r, color: C.primary),
            SizedBox(width: 8.r),
            Expanded(child: Text(product.isEmpty ? 'Add product' : product, style: sans(16, weight: FontWeight.w600))),
            Icon(Icons.edit_outlined, size: 18.r, color: C.onVariant),
          ]),
        ),
      );
}
