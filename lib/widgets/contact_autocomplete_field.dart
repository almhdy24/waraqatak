import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/contact.dart';

class ContactAutocompleteField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Autocomplete<Contact>(
      initialValue: TextEditingValue(text: initialContact?.name ?? ''),
      displayStringForOption: (contact) => contact.name,
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty) return const <Contact>[];
        return await DatabaseHelper.instance.searchContacts(textEditingValue.text, type: type);
      },
      onSelected: onContactChanged,
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label),
          onChanged: onTextChanged,
        );
      },
    );
  }
}