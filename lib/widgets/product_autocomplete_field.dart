import 'dart:async';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/product.dart';

class ProductAutocompleteField extends StatefulWidget {
  final String label;
  final ValueChanged<Product?> onProductSelected;

  const ProductAutocompleteField({
    super.key,
    required this.label,
    required this.onProductSelected,
  });

  @override
  State<ProductAutocompleteField> createState() =>
      _ProductAutocompleteFieldState();
}

class _ProductAutocompleteFieldState extends State<ProductAutocompleteField> {
  int _requestSequence = 0;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Product>(
      displayStringForOption: (product) => product.name,
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) return const <Product>[];

        final currentSeq = ++_requestSequence;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (currentSeq != _requestSequence) {
          return const <Product>[];
        }

        final results =
            await DatabaseHelper.instance.searchActiveProducts(query);
        if (currentSeq != _requestSequence) {
          return const <Product>[];
        }
        return results;
      },
      onSelected: widget.onProductSelected,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: widget.label),
        );
      },
    );
  }
}
