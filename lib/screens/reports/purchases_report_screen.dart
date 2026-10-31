import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/contact.dart';
import '../../models/currency.dart';
import '../../models/date_range_filter.dart';
import '../../models/document_status.dart';
import '../../services/business_reporting_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../../widgets/responsive.dart';
import '../document_detail_screen.dart';
import 'report_date_filter.dart';

class PurchasesReportScreen extends StatefulWidget {
  const PurchasesReportScreen({super.key});

  @override
  State<PurchasesReportScreen> createState() => _PurchasesReportScreenState();
}

class _PurchasesReportScreenState extends State<PurchasesReportScreen> {
  DateRangeFilter _range = DateRangeFilter.thisMonth();
  PurchaseReportSummary? _summary;
  List<Contact> _suppliers = [];
  int? _selectedSupplierId;
  String _selectedDocStatus = 'all';
  String _selectedPaymentStatus = 'all';
  String? _error;
  bool _loading = true;

  static final _numFmt = NumberFormat('#,##0.##');
  static final _dateFmt = DateFormat('dd/MM/yy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = await Future.wait([
        DatabaseHelper.instance.getAllContacts(type: 'supplier'),
        BusinessReportingService.instance.getPurchasesReport(
          from: _range.from,
          to: _range.to,
          supplierId: _selectedSupplierId,
          documentStatus: _selectedDocStatus,
          paymentStatus: _selectedPaymentStatus,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _suppliers = futures[0] as List<Contact>;
        _summary = futures[1] as PurchaseReportSummary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    final l10n = AppLocalizations.of(context);
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null || _summary == null) return;

    final columns = [
      PdfReportColumn(title: l10n.date, flex: 1.2),
      PdfReportColumn(title: l10n.documentNumber, flex: 1.6),
      PdfReportColumn(title: l10n.supplier, flex: 2.2),
      PdfReportColumn(title: l10n.status, flex: 1.2),
      PdfReportColumn(title: l10n.total, flex: 1.4, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.paid, flex: 1.4, align: pw.TextAlign.right),
      PdfReportColumn(title: l10n.remaining, flex: 1.4, align: pw.TextAlign.right),
    ];

    final rows = _summary!.items.map((item) {
      final doc = item.document;
      return [
        _dateFmt.format(doc.date),
        doc.documentNumber,
        item.supplierName ?? '—',
        doc.status == DocumentStatus.cancelled ? l10n.cancelledCount : l10n.issued,
        '${_numFmt.format(doc.total)} ${doc.currencySymbol}',
        '${_numFmt.format(doc.paid)} ${doc.currencySymbol}',
        '${_numFmt.format(doc.remaining)} ${doc.currencySymbol}',
      ];
    }).toList();

    final hasMultipleCurrencies = _summary!.currencies.length > 1;

    final data = PdfReportData(
      title: l10n.purchasesReport,
      subtitle: _selectedSupplierId != null
          ? _suppliers.where((s) => s.id == _selectedSupplierId).firstOrNull?.name
          : l10n.allSuppliers,
      dateRange: _range.label(l10n),
      warningNotice: hasMultipleCurrencies ? l10n.mixedCurrenciesNotice : null,
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.totalPurchasesAmt,
          value: hasMultipleCurrencies
              ? _summary!.totalsByCurrency.entries
                  .map((e) => '${_numFmt.format(e.value.purchases)} ${e.key}')
                  .join(' · ')
              : _numFmt.format(_summary!.totalPurchases),
        ),
        PdfReportSummaryCard(
          label: l10n.totalPaid,
          value: hasMultipleCurrencies
              ? _summary!.totalsByCurrency.entries
                  .map((e) => '${_numFmt.format(e.value.paid)} ${e.key}')
                  .join(' · ')
              : _numFmt.format(_summary!.totalPaid),
        ),
        PdfReportSummaryCard(
          label: l10n.totalOutstanding,
          value: hasMultipleCurrencies
              ? _summary!.totalsByCurrency.entries
                  .map((e) => '${_numFmt.format(e.value.remaining)} ${e.key}')
                  .join(' · ')
              : _numFmt.format(_summary!.totalRemaining),
        ),
      ],
      columns: columns,
      rows: rows,
      totalsRow: [
        l10n.total,
        '',
        '',
        '',
        hasMultipleCurrencies
            ? _summary!.totalsByCurrency.entries
                .map((e) => '${_numFmt.format(e.value.purchases)} ${e.key}')
                .join('\n')
            : _numFmt.format(_summary!.totalPurchases),
        hasMultipleCurrencies
            ? _summary!.totalsByCurrency.entries
                .map((e) => '${_numFmt.format(e.value.paid)} ${e.key}')
                .join('\n')
            : _numFmt.format(_summary!.totalPaid),
        hasMultipleCurrencies
            ? _summary!.totalsByCurrency.entries
                .map((e) => '${_numFmt.format(e.value.remaining)} ${e.key}')
                .join('\n')
            : _numFmt.format(_summary!.totalRemaining),
      ],
    );

    try {
      await PdfService.printOrShareReportPdf(
        business: business,
        l10n: l10n,
        data: data,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.operationFailed}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final summary = _summary;
    final totalPurchases = summary?.totalPurchases ?? 0.0;
    final totalPaid = summary?.totalPaid ?? 0.0;
    final totalRemaining = summary?.totalRemaining ?? 0.0;
    final cancelledCount = summary?.cancelledCount ?? 0;
    final finalizedCount = (summary?.items.length ?? 0) - cancelledCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.purchasesReport),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.printOrShareReport,
            onPressed: summary != null && summary.items.isNotEmpty ? _exportPdf : null,
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            // Date Filter
            ReportDateFilter(
              range: _range,
              onChanged: (r) {
                setState(() => _range = r);
                _load();
              },
            ),

            // Supplier Filter & Status Filter Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  // Supplier Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedSupplierId,
                          isExpanded: true,
                          hint: Text(l10n.allSuppliers, style: const TextStyle(fontSize: 12)),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(l10n.allSuppliers, style: const TextStyle(fontSize: 12)),
                            ),
                            ..._suppliers.map((s) => DropdownMenuItem<int?>(
                                  value: s.id,
                                  child: Text(s.name,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedSupplierId = val);
                            _load();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Document Status Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDocStatus,
                        items: [
                          DropdownMenuItem(value: 'all', child: Text(l10n.activeFilterAll, style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: DocumentStatus.issued, child: Text(l10n.statusIssued, style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: DocumentStatus.cancelled, child: Text(l10n.statusCancelled, style: const TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedDocStatus = val);
                            _load();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Payment Status Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPaymentStatus,
                        items: [
                          DropdownMenuItem(value: 'all', child: Text(l10n.activeFilterAll, style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'paid', child: Text(l10n.paidStatus, style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'partial', child: Text(l10n.partialStatus, style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'unpaid', child: Text(l10n.unpaidStatus, style: const TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPaymentStatus = val);
                            _load();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary Cards
            if (summary != null && summary.items.isNotEmpty) ...[
              if (summary.currencies.length <= 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    children: [
                      _chip(
                        l10n.totalPurchasesAmt,
                        totalPurchases,
                        Colors.orange,
                        symbol: summary.currencies.isNotEmpty
                            ? Currency.symbolForCode(summary.currencies.first)
                            : '',
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        l10n.totalPaid,
                        totalPaid,
                        Colors.teal,
                        symbol: summary.currencies.isNotEmpty
                            ? Currency.symbolForCode(summary.currencies.first)
                            : '',
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        l10n.totalOutstanding,
                        totalRemaining,
                        Theme.of(context).colorScheme.error,
                        symbol: summary.currencies.isNotEmpty
                            ? Currency.symbolForCode(summary.currencies.first)
                            : '',
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Column(
                    children: summary.totalsByCurrency.entries.map((e) {
                      final sym = Currency.symbolForCode(e.key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            _chip(
                              '${l10n.totalPurchasesAmt} (${e.key})',
                              e.value.purchases,
                              Colors.orange,
                              symbol: sym,
                            ),
                            const SizedBox(width: 8),
                            _chip(
                              '${l10n.totalPaid} (${e.key})',
                              e.value.paid,
                              Colors.teal,
                              symbol: sym,
                            ),
                            const SizedBox(width: 8),
                            _chip(
                              '${l10n.totalOutstanding} (${e.key})',
                              e.value.remaining,
                              Theme.of(context).colorScheme.error,
                              symbol: sym,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Text('${l10n.finalized}: $finalizedCount',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 12),
                    if (cancelledCount > 0)
                      Text('${l10n.cancelledCount}: $cancelledCount',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const Spacer(),
                    if (summary.currencies.length > 1)
                      Text(
                        l10n.mixedCurrenciesNotice,
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                      ),
                  ],
                ),
              ),
            ],

            // Purchases List
            Expanded(child: _buildList(context, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, double value, Color color, {String symbol = ''}) {
    final symStr = symbol.isNotEmpty ? ' $symbol' : '';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${_numFmt.format(value)}$symStr',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.operationFailed),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    final items = _summary?.items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(l10n.noDataForPeriod, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final doc = item.document;
        final isCancelled = doc.status == DocumentStatus.cancelled;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    doc.documentNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Text(
                  '${_numFmt.format(doc.total)} ${doc.currencySymbol}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.supplierName ?? '',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _dateFmt.format(doc.date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                if (!isCancelled) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${l10n.paid}: ${_numFmt.format(doc.paid)}',
                        style: const TextStyle(fontSize: 11, color: Colors.teal),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${l10n.remaining}: ${_numFmt.format(doc.remaining)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: doc.remaining > 0 ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: doc.id!)),
            ).then((_) => _load()),
          ),
        );
      },
    );
  }
}
