import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../models/document.dart';
import '../models/document_status.dart';
import 'contact_form_screen.dart';
import 'document_detail_screen.dart';
import 'invoice_screen.dart';
import 'purchase_screen.dart';
import 'activation_screen.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../utils/error_utils.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_section_header.dart';
import '../widgets/customer_statement_dialog.dart';
import '../widgets/pro_upgrade_sheet.dart';
import '../widgets/responsive.dart';
import '../widgets/status_badge.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Contact contact;
  const CustomerDetailScreen({super.key, required this.contact});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<Document>? _documents;
  Business? _business;
  double _outstanding = 0;
  Map<String, double> _outstandingByCurrency = {};
  String? _error;

  static final _fmt = NumberFormat('#,##0');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get _isSupplier => widget.contact.type == 'supplier';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _documents = null;
      _business = null;
      _outstanding = 0;
      _outstandingByCurrency = {};
      _error = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final docType = _isSupplier ? 'purchase' : 'invoice';
      final results = await Future.wait([
        db.getFirstBusiness(),
        db.getDocumentsByContact(widget.contact.id!),
        db.getContactOutstandingByCurrency(widget.contact.id!, docType),
      ]);
      if (!mounted) return;
      final biz = results[0] as Business?;
      final byCurrency = results[2] as Map<String, double>;
      final singleCurrencyOutstanding = byCurrency.length == 1
          ? byCurrency.values.first
          : (byCurrency.isEmpty ? 0.0 : 0.0);

      setState(() {
        _business = biz;
        _documents = results[1] as List<Document>;
        _outstandingByCurrency = byCurrency;
        _outstanding = singleCurrencyOutstanding;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _editContact() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactFormScreen(contact: widget.contact),
      ),
    );
    if (result == true && mounted) {
      _load();
      Navigator.pop(context, true);
    }
  }

  Future<void> _createDocument() async {
    if (_isSupplier) {
      final entitlement = await LicenseService.instance.checkEntitlement(
        force: true,
      );
      if (!mounted) return;
      if (!FeatureAccess.canAccess(Feature.purchases, entitlement)) {
        final result = await ProUpgradeSheet.show(
          context,
          feature: Feature.purchases,
        );
        if (result == true && mounted) {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ActivationScreen()),
          );
          if (!mounted) return;
          LicenseService.instance.invalidateCache();
        }
        return;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PurchaseScreen(preselectedContact: widget.contact),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceScreen(preselectedContact: widget.contact),
        ),
      );
    }
    if (mounted) {
      _load();
    }
  }

  Future<void> _openStatement() async {
    final entitlement = await LicenseService.instance.checkEntitlement(
      force: true,
    );
    if (!mounted) return;
    if (!FeatureAccess.canAccess(Feature.advancedReports, entitlement)) {
      final result = await ProUpgradeSheet.show(
        context,
        feature: Feature.advancedReports,
      );
      if (result == true && mounted) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const ActivationScreen()),
        );
        if (!mounted) return;
        LicenseService.instance.invalidateCache();
      }
      return;
    }
    if (!mounted) return;
    CustomerStatementDialog.show(context, contact: widget.contact);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final currency = _business?.currencySymbol ?? 'ج.س';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: _isSupplier
                ? l10n.supplierStatement
                : l10n.customerStatement,
            onPressed: _openStatement,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.edit,
            onPressed: _editContact,
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: _error != null
            ? _ErrorView(
                message: ErrorUtils.getFriendlyErrorMessage(
                  _error!,
                  l10n: l10n,
                ),
                onRetry: _load,
              )
            : _documents == null || _business == null
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context, l10n, cs, currency),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
    String currency,
  ) {
    final relevantType = _isSupplier ? 'purchase' : 'invoice';
    // Same scope as the outstanding balance: drafts and cancelled documents
    // are not amounts owed.
    final relevantDocs = _documents!
        .where(
          (d) =>
              d.type == relevantType &&
              d.status != DocumentStatus.draft &&
              d.status != DocumentStatus.cancelled,
        )
        .toList();
    final relevantCurrencies = relevantDocs.map((d) => d.currencyCode).toSet();
    final singleCurrency = relevantCurrencies.length == 1
        ? Currency.symbolForCode(relevantCurrencies.first)
        : (relevantCurrencies.isEmpty ? currency : null);
    final totalAmount = relevantDocs.fold<double>(0, (s, d) => s + d.total);
    final totalPaid = relevantDocs.fold<double>(0, (s, d) => s + d.paid);

    final avatarColor = _contactColor(widget.contact.name, cs);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        // ── Hero ──────────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                avatarColor.withValues(alpha: 0.9),
                avatarColor.withValues(alpha: 0.6),
              ],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Avatar + inactive badge
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials(widget.contact.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      ),
                    ),
                  ),
                  if (!widget.contact.active)
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.inactive,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.contact.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSupplier ? Icons.store_outlined : Icons.person_outline,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSupplier ? l10n.supplier : l10n.customer,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.contact.phone != null ||
                  widget.contact.email != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (widget.contact.phone != null)
                      _InfoChip(Icons.phone_outlined, widget.contact.phone!),
                    if (widget.contact.email != null)
                      _InfoChip(Icons.email_outlined, widget.contact.email!),
                    if (widget.contact.address != null)
                      _InfoChip(
                        Icons.location_on_outlined,
                        widget.contact.address!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Financial stats ───────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: _isSupplier ? l10n.purchase : l10n.invoice,
                value: singleCurrency != null
                    ? _fmt.format(totalAmount)
                    : '(${relevantCurrencies.length})',
                currency: singleCurrency ?? '',
                icon: _isSupplier
                    ? Icons.shopping_cart_outlined
                    : Icons.receipt_long_outlined,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: l10n.paid,
                value: singleCurrency != null
                    ? _fmt.format(totalPaid)
                    : '(${relevantCurrencies.length})',
                currency: singleCurrency ?? '',
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: _isSupplier ? l10n.payable : l10n.receivable,
                value: _outstandingByCurrency.length > 1
                    ? '(${_outstandingByCurrency.length})'
                    : _fmt.format(_outstanding),
                currency: _outstandingByCurrency.length == 1
                    ? Currency.symbolForCode(_outstandingByCurrency.keys.first)
                    : (_outstandingByCurrency.length > 1 ? '' : currency),
                icon: Icons.account_balance_wallet_outlined,
                color: (_outstanding > 0 || _outstandingByCurrency.isNotEmpty)
                    ? Colors.red.shade600
                    : Colors.grey,
                highlight:
                    _outstanding > 0 || _outstandingByCurrency.isNotEmpty,
              ),
            ),
          ],
        ),

        if (_outstandingByCurrency.length > 1) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.currency_exchange,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isSupplier ? l10n.payable : l10n.receivable,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _outstandingByCurrency.entries.map((e) {
                    final sym = Currency.symbolForCode(e.key);
                    return Chip(
                      label: Text(
                        '${_fmt.format(e.value)} $sym',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Notes ─────────────────────────────────────────────────────────
        if (widget.contact.notes != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notes_outlined,
                  size: 17,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.contact.notes!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Create document CTA ───────────────────────────────────────────
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _createDocument,
            icon: Icon(
              _isSupplier ? Icons.shopping_cart_outlined : Icons.receipt_long,
            ),
            label: Text(_isSupplier ? l10n.newPurchase : l10n.createInvoice),
          ),
        ),
        if (!_isSupplier) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _openStatement,
              icon: const Icon(Icons.assignment_outlined),
              label: Text(l10n.customerStatement),
            ),
          ),
        ],
        const SizedBox(height: 24),

        // ── Documents ─────────────────────────────────────────────────────
        AppSectionHeader(
          title: l10n.recentDocuments,
          count: _documents!.isNotEmpty ? _documents!.length : null,
        ),
        const SizedBox(height: 8),
        if (_documents!.isEmpty)
          AppEmptyState(
            icon: Icons.description_outlined,
            title: l10n.noDocuments,
            description: l10n.noDocumentsHint,
          )
        else
          ..._documents!.map(
            (doc) => _DocumentTile(
              doc: doc,
              currency: doc.currencySymbol,
              fmt: _fmt,
              dateFmt: _dateFmt,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentDetailScreen(documentId: doc.id!),
                ),
              ).then((_) => _load()),
            ),
          ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  Color _contactColor(String name, ColorScheme cs) {
    final colors = [
      cs.primary,
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.purple,
      Colors.green.shade700,
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String currency;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _StatCard({
    required this.label,
    required this.value,
    required this.currency,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: highlight
          ? color.withValues(alpha: 0.06)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
      border: Border.all(
        color: highlight
            ? color.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: highlight ? color : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          currency,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _DocumentTile extends StatelessWidget {
  final Document doc;
  final String currency;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  const _DocumentTile({
    required this.doc,
    required this.currency,
    required this.fmt,
    required this.dateFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconForType(doc.type),
                  size: 20,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.documentNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFmt.format(doc.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${fmt.format(doc.total)} ${doc.currencySymbol}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(status: doc.status),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                AppLocalizations.of(context).isArabic
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                size: 18,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) => switch (type) {
    'invoice' => Icons.receipt_long,
    'purchase' => Icons.shopping_cart_outlined,
    'quotation' => Icons.request_quote,
    'payment_receipt' => Icons.call_received,
    'expense_voucher' => Icons.money_off,
    _ => Icons.description,
  };
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context).retry),
        ),
      ],
    ),
  );
}
