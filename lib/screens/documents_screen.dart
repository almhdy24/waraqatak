import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/document.dart';
import '../models/document_status.dart';
import '../widgets/status_badge.dart';
import 'document_detail_screen.dart';

class DocumentsScreen extends StatefulWidget {
  final int refreshToken;
  const DocumentsScreen({super.key, this.refreshToken = 0});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Document>? _documents;
  String _filterType = 'all';
  String _query = '';
  String? _error;

  static final _numFmt = NumberFormat('#,##0.##');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DocumentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    setState(() {
      _documents = null;
      _error = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final List<Document> docs;
      if (_query.isNotEmpty) {
        docs = await db.searchDocuments(_query,
            type: _filterType == 'all' ? null : _filterType);
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: '${l10n.search}...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                isDense: true,
              ),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _chip('all', l10n.all),
                _chip('invoice', l10n.invoice),
                _chip('purchase', l10n.purchase),
                _chip('quotation', l10n.quotation),
                _chip('payment_receipt', l10n.paymentReceipt),
                _chip('expense_voucher', l10n.expenseVoucher),
                _chip('custom', l10n.customDocument),
              ],
            ),
          ),
          Expanded(child: _buildList(l10n)),
        ],
      ),
    );
  }

  Widget _buildList(AppLocalizations l10n) {
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

    final docs = _documents!;
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.description_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                _query.isNotEmpty ? l10n.noSearchResults : l10n.noDocumentsTitle,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _query.isNotEmpty ? l10n.noSearchResultsHint : l10n.noDocumentsHint,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: docs.length,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemBuilder: (ctx, i) {
        final doc = docs[i];
        final showRemaining = (doc.type == 'invoice' || doc.type == 'purchase') &&
            doc.status != DocumentStatus.paid &&
            doc.status != DocumentStatus.cancelled &&
            doc.remaining > 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(ctx).colorScheme.primaryContainer,
              child: Icon(_iconFor(doc.type),
                  size: 20, color: Theme.of(ctx).colorScheme.primary),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(doc.documentNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text(
                  '${_numFmt.format(doc.total)} ${doc.currencySymbol}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (doc.recipientName != null && doc.recipientName!.isNotEmpty)
                  Text(doc.recipientName!,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(_dateFmt.format(doc.date),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                    const Spacer(),
                    StatusBadge(status: doc.status),
                  ],
                ),
                if (showRemaining)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${l10n.remaining}: ${_numFmt.format(doc.remaining)} ${doc.currencySymbol}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.error,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => DocumentDetailScreen(documentId: doc.id!),
                ),
              );
              _load();
            },
          ),
        );
      },
    );
  }

  Widget _chip(String type, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ChoiceChip(
        label: Text(label),
        selected: _filterType == type,
        onSelected: (_) {
          setState(() => _filterType = type);
          _load();
        },
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'invoice'         => Icons.receipt_long_rounded,
      'purchase'        => Icons.shopping_cart_outlined,
      'quotation'       => Icons.request_quote_rounded,
      'payment_receipt' => Icons.call_received_rounded,
      'expense_voucher' => Icons.money_off_rounded,
      'custom'          => Icons.description_rounded,
      _                 => Icons.description_rounded,
    };
  }
}
