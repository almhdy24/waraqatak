import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/contact.dart';

class ContactAutocompleteField extends StatefulWidget {
  final Contact? initialContact;
  final String label;
  final String type;
  final ValueChanged<Contact?> onContactChanged;
  final ValueChanged<String>? onTextChanged;

  const ContactAutocompleteField({
    super.key,
    this.initialContact,
    required this.label,
    required this.type,
    required this.onContactChanged,
    this.onTextChanged,
  });

  @override
  State<ContactAutocompleteField> createState() =>
      _ContactAutocompleteFieldState();
}

class _ContactAutocompleteFieldState extends State<ContactAutocompleteField> {
  Contact? _selectedContact;

  @override
  void initState() {
    super.initState();
    _selectedContact = widget.initialContact;
  }

  @override
  void didUpdateWidget(covariant ContactAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialContact != widget.initialContact) {
      _selectedContact = widget.initialContact;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Contact>(
      initialValue: TextEditingValue(text: widget.initialContact?.name ?? ''),
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
        widget.onContactChanged(contact);
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
