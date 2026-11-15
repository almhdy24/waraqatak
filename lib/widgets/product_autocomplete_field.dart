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
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Product>(
      displayStringForOption: (product) => product.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) return const <Product>[];

        final currentSeq = ++_requestSequence;
        final completer = Completer<Iterable<Product>>();
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
          if (currentSeq != _requestSequence || !mounted) {
            completer.complete(const <Product>[]);
            return;
          }
          try {
            final results =
                await DatabaseHelper.instance.searchActiveProducts(query);
            if (currentSeq != _requestSequence || !mounted) {
              completer.complete(const <Product>[]);
            } else {
              completer.complete(results);
            }
          } catch (_) {
            completer.complete(const <Product>[]);
          }
        });
        return completer.future;
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
