import 'dart:async';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/product.dart';

class ProductAutocompleteField extends StatefulWidget {
  final String label;
  final ValueChanged<Product?> onProductSelected;
  final TextEditingController? controller;
  final ValueChanged<String>? onTextChanged;

  const ProductAutocompleteField({
    super.key,
    required this.label,
    required this.onProductSelected,
    this.controller,
    this.onTextChanged,
  });

  @override
  State<ProductAutocompleteField> createState() =>
      _ProductAutocompleteFieldState();
}

class _ProductAutocompleteFieldState extends State<ProductAutocompleteField> {
  TextEditingController? _internalController;
  int _requestSequence = 0;
  Timer? _debounceTimer;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _effectiveController.addListener(_onControllerTextChanged);
  }

  void _onControllerTextChanged() {
    widget.onTextChanged?.call(_effectiveController.text);
  }

  @override
  void didUpdateWidget(covariant ProductAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerTextChanged);
      _internalController?.removeListener(_onControllerTextChanged);

      if (widget.controller == null && _internalController == null) {
        _internalController = TextEditingController();
      }
      _effectiveController.addListener(_onControllerTextChanged);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _effectiveController.removeListener(_onControllerTextChanged);
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Product>(
      key: ValueKey(_effectiveController),
      textEditingController: _effectiveController,
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
      onSelected: (product) {
        widget.onProductSelected(product);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: widget.label),
          onFieldSubmitted: (value) {
            // Prevent RawAutocomplete from auto-selecting the top suggestion on submit.
            // Selection must be explicit by tapping the suggestion.
          },
        );
      },
    );
  }
}
