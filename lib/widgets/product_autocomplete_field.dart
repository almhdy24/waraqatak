import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/product.dart';

class ProductAutocompleteField extends StatelessWidget {
  final String label;
  final ValueChanged<Product?> onProductSelected;

  const ProductAutocompleteField({
    super.key,
    required this.label,
    required this.onProductSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Product>(
      displayStringForOption: (product) => product.name,
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty) return const <Product>[];
        return DatabaseHelper.instance.searchActiveProducts(textEditingValue.text);
      },
      onSelected: onProductSelected,
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label),
        );
      },
    );
  }
}
