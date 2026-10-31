import 'dart:async';
import 'package:flutter/material.dart';
import 'app_design_tokens.dart';

/// Standard, high-performance debounced search bar for Waraqatak.
class AppSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final Duration debounceDuration;
  final String? initialValue;

  const AppSearchBar({
    super.key,
    required this.hintText,
    this.onSearch,
    this.onChanged,
    this.onClear,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.initialValue,
  }) : assert(onSearch != null || onChanged != null, 'Either onSearch or onChanged must be provided');

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // update clear button visibility
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      final callback = widget.onChanged ?? widget.onSearch;
      callback?.call(value.trim());
    });
  }

  void _clear() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() {});
    (widget.onChanged ?? widget.onSearch)?.call('');
    if (widget.onClear != null) {
      widget.onClear!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppDesignTokens.br12,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: AppDesignTokens.softShadow(context),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: cs.onSurfaceVariant,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                  color: cs.onSurfaceVariant,
                  onPressed: _clear,
                )
              : null,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.space12,
            vertical: AppDesignTokens.space12,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
