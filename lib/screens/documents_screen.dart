import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/document.dart';
import 'document_detail_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Document>? _documents;
  String _filterType = 'all';
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _documents = null; _error = null; });
    try {
      final db = DatabaseHelper.instance;
      List<Document> docs;
      if (_query.isNotEmpty) {
        docs = await db.searchDocuments(_query, type: _filterType == 'all' ? null : _filterType);
      } else if (_filterType == 'all') {
        docs = await db.getAllDocuments();
      } else {
        docs = await db.getDocumentsByType(_filterType);
      }
      if (!mounted) return;
      setState(() => _documents = docs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documents), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) { _query = v; _load(); },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _filterChip('all', l10n.all),
                _filterChip('invoice', l10n.invoice),
                _filterChip('quotation', l10n.quotation),
                _filterChip('payment_receipt', l10n.paymentReceipt),
                _filterChip('expense_voucher', l10n.expenseVoucher),
                _filterChip('custom', l10n.customDocument),
              ],
            ),
          ),
          Expanded(child: _buildList(context, l10n)),
        ],
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
            ElevatedButton(onPressed: _load, child: Text(l10n.cancel)),
          ],
        ),
      );
    }
    if (_documents == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final documents = _documents!;
    if (documents.isEmpty) {
      return Center(child: Text(l10n.noDocuments));
    }
    return ListView.builder(
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Icon(_iconForType(doc.type)),
            title: Text(doc.documentNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${doc.recipientName ?? ''} - ${NumberFormat('#,##0').format(doc.total)} ${doc.currencySymbol}'),
            trailing: Text(DateFormat('dd/MM/yyyy').format(doc.date), style: const TextStyle(fontSize: 12)),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: doc.id!)));
              _load();
            },
          ),
        );
      },
    );
  }

  Widget _filterChip(String type, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: _filterType == type,
        onSelected: (_) { setState(() => _filterType = type); _load(); },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'invoice': return Icons.receipt_long;
      case 'quotation': return Icons.request_quote;
      case 'payment_receipt': return Icons.call_received;
      case 'expense_voucher': return Icons.money_off;
      case 'custom': return Icons.description;
      default: return Icons.description;
    }
  }
}
