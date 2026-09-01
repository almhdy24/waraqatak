import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/contact.dart';
import 'contact_form_screen.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Contact>? _contacts;
  String _query = '';
  String _filterType = 'customer';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _contacts = null;
      _error = null;
    });

    try {
      final db = DatabaseHelper.instance;
      List<Contact> contacts;
      if (_query.isNotEmpty) {
        contacts = await db.searchContacts(_query, type: _filterType);
      } else {
        contacts = await db.getAllContacts();
        contacts = contacts.where((c) => c.type == _filterType).toList();
      }

      if (!mounted) return;
      setState(() {
        _contacts = contacts;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteCustomerMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DatabaseHelper.instance.deleteContact(contact.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.operationSuccessful)),
        );
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.operationFailed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customers),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                _query = value;
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text(l10n.customer),
                    selected: _filterType == 'customer',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _filterType = 'customer');
                        _load();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text(l10n.supplier),
                    selected: _filterType == 'supplier',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _filterType = 'supplier');
                        _load();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(context, l10n)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_customers',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactFormScreen()),
          );
          _load();
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.operationFailed),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
    }

    if (_contacts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final contacts = _contacts!;
    if (contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(l10n.noCustomers),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                contact.type == 'supplier' ? Icons.store : Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              contact.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              contact.phone ?? '',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteContact(contact),
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerDetailScreen(contact: contact),
                ),
              );
              _load();
            },
          ),
        );
      },
    );
  }
}