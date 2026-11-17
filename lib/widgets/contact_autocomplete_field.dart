import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/contact.dart';

class ContactAutocompleteField extends StatefulWidget {
  final Contact? initialContact;
  final String? initialText;
  final TextEditingController? controller;
  final String label;
  final String type;
  final ValueChanged<Contact?> onContactChanged;
  final ValueChanged<String>? onTextChanged;

  const ContactAutocompleteField({
    super.key,
    this.initialContact,
    this.initialText,
    this.controller,
    required this.label,
    required this.type,
    required this.onContactChanged,
    this.onTextChanged,
  });

  @override
  State<ContactAutocompleteField> createState() =>
      _ContactAutocompleteFieldState();
}

class _ContactAutocompleteFieldState extends State<ContactAutocompleteField>
    with AutomaticKeepAliveClientMixin {
  final FocusNode _focusNode = FocusNode();
  TextEditingController? _internalController;
  Contact? _selectedContact;

  TextEditingController get _effectiveController =>
      widget.controller ??
      (_internalController ??= TextEditingController(
        text: widget.initialText ?? widget.initialContact?.name ?? '',
      ));

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedContact = widget.initialContact;
    if (widget.controller == null) {
      _internalController = TextEditingController(
        text: widget.initialText ?? widget.initialContact?.name ?? '',
      );
    } else {
      if (widget.controller!.text.isEmpty) {
        final text = widget.initialText ?? widget.initialContact?.name;
        if (text != null && text.isNotEmpty) {
          widget.controller!.text = text;
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant ContactAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (widget.controller == null && _internalController == null) {
        _internalController = TextEditingController(
          text: widget.initialText ?? widget.initialContact?.name ?? '',
        );
      }
    }

    if (oldWidget.initialContact != widget.initialContact) {
      _selectedContact = widget.initialContact;
      if (widget.initialContact != null &&
          _effectiveController.text != widget.initialContact!.name) {
        _effectiveController.text = widget.initialContact!.name;
      }
    } else if (oldWidget.initialText != widget.initialText &&
        widget.initialText != null &&
        _effectiveController.text != widget.initialText) {
      _effectiveController.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Autocomplete<Contact>(
      key: ValueKey(_effectiveController),
      focusNode: _focusNode,
      textEditingController: _effectiveController,
      displayStringForOption: (contact) => contact.name,
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) return const <Contact>[];
        // If text matches the currently selected contact name, do not show suggestions
        if (_selectedContact != null &&
            query == _selectedContact!.name.trim()) {
          return const <Contact>[];
        }
        return await DatabaseHelper.instance.searchContacts(
          query,
          type: widget.type,
        );
      },
      onSelected: (contact) {
        setState(() {
          _selectedContact = contact;
        });
        _effectiveController.text = contact.name;
        widget.onContactChanged(contact);
        widget.onTextChanged?.call(contact.name);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: widget.label),
          onChanged: (text) {
            if (_selectedContact != null &&
                text.trim() != _selectedContact!.name.trim()) {
              setState(() {
                _selectedContact = null;
              });
              widget.onContactChanged(null);
            }
            widget.onTextChanged?.call(text);
          },
        );
      },
    );
  }
}
