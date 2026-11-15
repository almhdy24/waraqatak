import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/document.dart';
import '../models/document_status.dart';
import '../utils/error_utils.dart';
import '../widgets/app_amount_text.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/status_badge.dart';
import 'document_detail_screen.dart';
import '../widgets/responsive.dart';

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
  bool _isLoading = false;
  int _searchVersion = 0;
  bool _onlyUnpaid = false;
  DateTimeRange? _dateRange;

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
    final currentVersion = ++_searchVersion;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final List<Document> docs;
      if (_query.isNotEmpty) {
        docs = await db.searchDocuments(
          _query,
          type: _filterType == 'all' ? null : _filterType,
        );
      } else if (_filterType == 'all') {
        docs = await db.getAllDocuments();
      } else {
        docs = await db.getDocumentsByType(_filterType);
      }
      if (!mounted || currentVersion != _searchVersion) return;
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentVersion != _searchVersion) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documents), centerTitle: true),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: AppSearchBar(
                hintText: '${l10n.search}...',
                onChanged: (v) {
                  _query = v;
                  _load();
                },
                onClear: () {
                  _query = '';
                  _load();
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  _chip('all', l10n.all),
                  _chip('invoice', l10n.invoice),
                  _chip('purchase', l10n.purchase),
                  _chip('quotation', l10n.quotation),
                  _chip('payment_receipt', l10n.paymentReceipt),
                  _chip('expense_voucher', l10n.expenseVoucher),
                  _chip('custom', l10n.customDocument),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.money_off, size: 16),
                    label: Text(l10n.unpaidStatus),
                    selected: _onlyUnpaid,
                    onSelected: (selected) {
                      setState(() => _onlyUnpaid = selected);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      _dateRange == null
                          ? l10n.date
                          : '${_dateFmt.format(_dateRange!.start)} - ${_dateFmt.format(_dateRange!.end)}',
                    ),
                    selected: _dateRange != null,
                    onSelected: (_) async {
                      if (_dateRange != null) {
                        setState(() => _dateRange = null);
                      } else {
                        await _pickDateRange(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            if (_isLoading && _documents != null)
              const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 4),
            Expanded(child: _buildList(l10n, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AppLocalizations l10n, ThemeData theme) {
    if (_error != null && _documents == null) {
      return AppErrorState(
        message: ErrorUtils.toFriendlyMessage(_error!, l10n),
        onRetry: _load,
      );
    }

    if (_documents == null) {
      return const AppLoadingView();
    }

    final rawDocs = _documents!;
    final docs = rawDocs.where((doc) {
      if (_onlyUnpaid) {
        final canBeUnpaid = doc.type == 'invoice' || doc.type == 'purchase';
        if (!canBeUnpaid ||
            doc.remaining <= 0 ||
            doc.status == DocumentStatus.paid ||
            doc.status == DocumentStatus.cancelled) {
          return false;
        }
      }
      if (_dateRange != null) {
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final end = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
          23,
          59,
          59,
          999,
        );
        if (doc.date.isBefore(start) || doc.date.isAfter(end)) {
          return false;
        }
      }
      return true;
    }).toList();
    if (docs.isEmpty) {
      if (_query.isNotEmpty) {
        return AppEmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.noSearchResults,
          description: l10n.noSearchResultsHint,
        );
      }
      return AppEmptyState(
        icon: Icons.description_outlined,
        title: l10n.noDocumentsTitle,
        description: l10n.noDocumentsHint,
      );
    }

    return ListView.builder(
      itemCount: docs.length,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemBuilder: (ctx, i) {
        final doc = docs[i];
        final showRemaining =
            (doc.type == 'invoice' || doc.type == 'purchase') &&
            doc.status != DocumentStatus.paid &&
            doc.status != DocumentStatus.cancelled &&
            doc.remaining > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
            onTap: () async {
              await Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => DocumentDetailScreen(documentId: doc.id!),
                ),
              );
              _load();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDesignTokens.smallRadius,
                          ),
                        ),
                        child: Icon(
                          _iconFor(doc.type),
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.documentNumber,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (doc.recipientName != null &&
                                doc.recipientName!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  doc.recipientName!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppAmountText(
                            amount: doc.total,
                            currencySymbol: doc.currencySymbol,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          const SizedBox(height: 4),
                          StatusBadge(status: doc.status),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _dateFmt.format(doc.date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (showRemaining)
                        Text(
                          '${l10n.remaining}: ${_numFmt.format(doc.remaining)} ${doc.currencySymbol}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String type, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
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
      'invoice' => Icons.receipt_long_rounded,
      'purchase' => Icons.shopping_cart_outlined,
      'quotation' => Icons.request_quote_rounded,
      'payment_receipt' => Icons.call_received_rounded,
      'expense_voucher' => Icons.money_off_rounded,
      'custom' => Icons.description_rounded,
      _ => Icons.description_rounded,
    };
  }
}
