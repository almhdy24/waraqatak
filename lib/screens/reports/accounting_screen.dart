import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/currency.dart';
import '../../models/date_range_filter.dart';
import '../../services/accounting/ledger.dart';
import '../../services/accounting/ledger_service.dart';
import '../../services/csv_service.dart';
import '../../services/pdf/pdf_report_builder.dart';
import '../../services/pdf_service.dart';
import '../../widgets/access/screen_access_gate.dart';
import '../../widgets/app_design_tokens.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_loading_view.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_status_colors.dart';
import '../../widgets/report_export_menu.dart';
import '../../widgets/responsive.dart';
import 'report_date_filter.dart';
import 'reports_date_scope.dart';

final _amountFmt = NumberFormat('#,##0.00');
final _dateFmt = DateFormat('dd/MM/yy');

/// Accounting amounts: negatives in parentheses, tiny residues shown as 0.
String formatAmount(double v) {
  if (v.abs() < 0.005) return _amountFmt.format(0);
  return v < 0 ? '(${_amountFmt.format(-v)})' : _amountFmt.format(v);
}

String entrySourceLabel(EntrySource s, AppLocalizations l10n) => switch (s) {
  EntrySource.invoice => l10n.invoice,
  EntrySource.invoicePayment => l10n.entryInvoicePayment,
  EntrySource.receipt => l10n.paymentReceipt,
  EntrySource.purchase => l10n.purchase,
  EntrySource.purchasePayment => l10n.entryPurchasePayment,
  EntrySource.expenseVoucher => l10n.expenseVoucher,
  EntrySource.costOfSales => l10n.entryCostOfSales,
  EntrySource.openingStock => l10n.entryOpeningStock,
  EntrySource.stockAdjustment => l10n.entryStockAdjustment,
};

/// Financial statements derived from the double-entry ledger.
class AccountingScreen extends StatefulWidget {
  /// Period shown first; defaults to this month.
  final DateRangeFilter? initialRange;

  const AccountingScreen({super.key, this.initialRange});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen>
    with SingleTickerProviderStateMixin {
  late DateRangeFilter _range =
      widget.initialRange ?? ReportsDateNotifier.instance.range;
  LedgerBook? _book;
  bool _failed = false;
  int _querySeq = 0;
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_querySeq;
    setState(() => _failed = false);
    try {
      final book = await LedgerService.load();
      if (!mounted || seq != _querySeq) return;
      setState(() => _book = book);
    } catch (_) {
      if (!mounted || seq != _querySeq) return;
      setState(() => _failed = true);
    }
  }

  PdfReportData _buildActiveTabPdfData(
    AppLocalizations l10n,
    LedgerBook book,
    String symbol,
    String asOf,
  ) {
    final entries = book.entries;
    final tabIndex = _tabController.index;

    if (tabIndex == 0) {
      final statement = AccountingReports.incomeStatement(
        entries,
        from: _range.from,
        to: _range.to,
      );
      return PdfReportData(
        title: l10n.incomeStatement,
        dateRange: _range.label(l10n),
        summaryCards: [
          PdfReportSummaryCard(
            label: l10n.revenueSection,
            value: '${formatAmount(statement.salesRevenue)} $symbol',
          ),
          PdfReportSummaryCard(
            label: l10n.cogs,
            value: '${formatAmount(statement.costOfSales)} $symbol',
          ),
          PdfReportSummaryCard(
            label: l10n.grossProfit,
            value: '${formatAmount(statement.grossProfit)} $symbol',
          ),
          PdfReportSummaryCard(
            label: l10n.netProfit,
            value: '${formatAmount(statement.netProfit)} $symbol',
          ),
        ],
        columns: [
          PdfReportColumn(title: l10n.accountColumn, flex: 2.5),
          PdfReportColumn(
            title: l10n.accountBalance,
            flex: 1.5,
            align: pw.TextAlign.right,
          ),
        ],
        rows: [
          [
            l10n.revenueSection,
            '${formatAmount(statement.salesRevenue)} $symbol',
          ],
          if (statement.otherIncome > 0)
            ['Other Income', '${formatAmount(statement.otherIncome)} $symbol'],
          [l10n.cogs, '${formatAmount(statement.costOfSales)} $symbol'],
          [l10n.grossProfit, '${formatAmount(statement.grossProfit)} $symbol'],
          if (statement.operatingExpenses > 0)
            [
              l10n.expensesSection,
              '${formatAmount(statement.operatingExpenses)} $symbol',
            ],
          [l10n.netProfit, '${formatAmount(statement.netProfit)} $symbol'],
        ],
      );
    } else if (tabIndex == 1) {
      final sheet = AccountingReports.balanceSheet(entries, asOf: _range.to);
      return PdfReportData(
        title: l10n.balanceSheet,
        dateRange: asOf,
        summaryCards: [
          PdfReportSummaryCard(
            label: l10n.totalAssets,
            value: '${formatAmount(sheet.totalAssets)} $symbol',
          ),
          PdfReportSummaryCard(
            label: l10n.totalLiabilitiesEquity,
            value:
                '${formatAmount(sheet.totalLiabilities + sheet.totalEquity)} $symbol',
          ),
        ],
        columns: [
          PdfReportColumn(title: l10n.accountColumn, flex: 2.5),
          PdfReportColumn(
            title: l10n.accountBalance,
            flex: 1.5,
            align: pw.TextAlign.right,
          ),
        ],
        rows: [
          ...sheet.assets.entries.map(
            (e) => [
              l10n.accountName(e.key.code),
              '${formatAmount(e.value)} $symbol',
            ],
          ),
          ...sheet.liabilities.entries.map(
            (e) => [
              l10n.accountName(e.key.code),
              '${formatAmount(e.value)} $symbol',
            ],
          ),
          ...sheet.equity.entries.map(
            (e) => [
              l10n.accountName(e.key.code),
              '${formatAmount(e.value)} $symbol',
            ],
          ),
          if (sheet.retainedEarnings != 0)
            [
              l10n.retainedEarnings,
              '${formatAmount(sheet.retainedEarnings)} $symbol',
            ],
        ],
      );
    } else if (tabIndex == 2) {
      final trial = AccountingReports.trialBalance(entries, to: _range.to);
      return PdfReportData(
        title: l10n.trialBalance,
        dateRange: asOf,
        summaryCards: [
          PdfReportSummaryCard(
            label: l10n.debit,
            value: '${formatAmount(trial.totalDebit)} $symbol',
          ),
          PdfReportSummaryCard(
            label: l10n.credit,
            value: '${formatAmount(trial.totalCredit)} $symbol',
          ),
        ],
        columns: [
          PdfReportColumn(title: l10n.accountCode, flex: 1.0),
          PdfReportColumn(title: l10n.accountColumn, flex: 2.2),
          PdfReportColumn(
            title: l10n.debit,
            flex: 1.4,
            align: pw.TextAlign.right,
          ),
          PdfReportColumn(
            title: l10n.credit,
            flex: 1.4,
            align: pw.TextAlign.right,
          ),
        ],
        rows: trial.rows
            .map(
              (r) => [
                r.account.code,
                l10n.accountName(r.account.code),
                r.debit > 0 ? formatAmount(r.debit) : '—',
                r.credit > 0 ? formatAmount(r.credit) : '—',
              ],
            )
            .toList(),
      );
    } else {
      final accounts = Accounts.all;
      return PdfReportData(
        title: l10n.chartOfAccounts,
        dateRange: asOf,
        columns: [
          PdfReportColumn(title: l10n.accountCode, flex: 1.0),
          PdfReportColumn(title: l10n.accountColumn, flex: 2.5),
          PdfReportColumn(title: l10n.status, flex: 1.5),
        ],
        rows: accounts
            .map(
              (a) => [
                a.code,
                l10n.accountName(a.code),
                _accountTypeName(a.type, l10n),
              ],
            )
            .toList(),
      );
    }
  }

  Future<void> _exportPdf(
    AppLocalizations l10n,
    LedgerBook book,
    String symbol,
    String asOf, {
    required bool isShare,
  }) async {
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null) return;
    final data = _buildActiveTabPdfData(l10n, book, symbol, asOf);
    try {
      if (isShare) {
        await PdfService.shareReportPdf(
          business: business,
          l10n: l10n,
          data: data,
        );
      } else {
        await PdfService.printOrShareReportPdf(
          business: business,
          l10n: l10n,
          data: data,
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          l10n.operationFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _shareWhatsApp(
    AppLocalizations l10n,
    LedgerBook book,
    String symbol,
    String asOf,
  ) async {
    final entries = book.entries;
    final tabIndex = _tabController.index;
    String text;
    if (tabIndex == 0) {
      final st = AccountingReports.incomeStatement(
        entries,
        from: _range.from,
        to: _range.to,
      );
      text =
          '${l10n.incomeStatement} · ${_range.label(l10n)}\n'
          '${l10n.revenueSection}: ${formatAmount(st.salesRevenue)} $symbol\n'
          '${l10n.cogs}: ${formatAmount(st.costOfSales)} $symbol\n'
          '${l10n.grossProfit}: ${formatAmount(st.grossProfit)} $symbol\n'
          '${l10n.netProfit}: ${formatAmount(st.netProfit)} $symbol';
    } else if (tabIndex == 1) {
      final sh = AccountingReports.balanceSheet(entries, asOf: _range.to);
      text =
          '${l10n.balanceSheet} · $asOf\n'
          '${l10n.totalAssets}: ${formatAmount(sh.totalAssets)} $symbol\n'
          '${l10n.liabilitiesSection}: ${formatAmount(sh.totalLiabilities)} $symbol\n'
          '${l10n.equitySection}: ${formatAmount(sh.totalEquity)} $symbol';
    } else if (tabIndex == 2) {
      final tb = AccountingReports.trialBalance(entries, to: _range.to);
      text =
          '${l10n.trialBalance} · $asOf\n'
          '${l10n.debit}: ${formatAmount(tb.totalDebit)} $symbol\n'
          '${l10n.credit}: ${formatAmount(tb.totalCredit)} $symbol';
    } else {
      text = '${l10n.chartOfAccounts} · $asOf\n${Accounts.all.length} accounts';
    }
    await PdfService.shareText(text: text);
  }

  Future<void> _exportCsv(
    AppLocalizations l10n,
    LedgerBook book,
    String symbol,
    String asOf,
  ) async {
    final entries = book.entries;
    final tabIndex = _tabController.index;
    late List<String> headers;
    late List<List<dynamic>> rows;
    late String fileName;

    if (tabIndex == 0) {
      final st = AccountingReports.incomeStatement(
        entries,
        from: _range.from,
        to: _range.to,
      );
      headers = [l10n.accountColumn, l10n.amount, l10n.currency];
      rows = [
        [l10n.revenueSection, st.salesRevenue, book.currencyCode],
        if (st.otherIncome > 0)
          ['Other Income', st.otherIncome, book.currencyCode],
        [l10n.cogs, st.costOfSales, book.currencyCode],
        [l10n.grossProfit, st.grossProfit, book.currencyCode],
        if (st.operatingExpenses > 0)
          [l10n.expensesSection, st.operatingExpenses, book.currencyCode],
        [l10n.netProfit, st.netProfit, book.currencyCode],
      ];
      fileName =
          'income_statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    } else if (tabIndex == 1) {
      final sh = AccountingReports.balanceSheet(entries, asOf: _range.to);
      headers = [l10n.accountColumn, l10n.amount, l10n.currency];
      rows = [
        ...sh.assets.entries.map(
          (e) => [l10n.accountName(e.key.code), e.value, book.currencyCode],
        ),
        ...sh.liabilities.entries.map(
          (e) => [l10n.accountName(e.key.code), e.value, book.currencyCode],
        ),
        ...sh.equity.entries.map(
          (e) => [l10n.accountName(e.key.code), e.value, book.currencyCode],
        ),
        if (sh.retainedEarnings != 0)
          [l10n.retainedEarnings, sh.retainedEarnings, book.currencyCode],
      ];
      fileName =
          'balance_sheet_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    } else if (tabIndex == 2) {
      final tb = AccountingReports.trialBalance(entries, to: _range.to);
      headers = [l10n.accountCode, l10n.accountColumn, l10n.debit, l10n.credit];
      rows = tb.rows
          .map(
            (r) => [
              r.account.code,
              l10n.accountName(r.account.code),
              r.debit,
              r.credit,
            ],
          )
          .toList();
      fileName =
          'trial_balance_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    } else {
      headers = [l10n.accountCode, l10n.accountColumn, l10n.status];
      rows = Accounts.all
          .map(
            (a) => [
              a.code,
              l10n.accountName(a.code),
              _accountTypeName(a.type, l10n),
            ],
          )
          .toList();
      fileName =
          'chart_of_accounts_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    }

    try {
      final bytes = CsvService.instance.exportReportToCsv(
        headers: headers,
        rows: rows,
      );
      await PdfService.shareCsv(bytes: bytes, fileName: fileName);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          l10n.operationFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  String _accountTypeName(AccountType type, AppLocalizations l10n) {
    switch (type) {
      case AccountType.asset:
        return l10n.assetsSection;
      case AccountType.liability:
        return l10n.liabilitiesSection;
      case AccountType.equity:
        return l10n.equitySection;
      case AccountType.revenue:
        return l10n.revenueSection;
      case AccountType.expense:
        return l10n.expensesSection;
    }
  }

  void _openExportMenu(
    BuildContext context,
    AppLocalizations l10n,
    LedgerBook book,
    String symbol,
    String asOf,
  ) {
    ReportExportMenu.show(
      context: context,
      title: l10n.accounting,
      onPrintPdf: () => _exportPdf(l10n, book, symbol, asOf, isShare: false),
      onSharePdf: () => _exportPdf(l10n, book, symbol, asOf, isShare: true),
      onShareWhatsApp: () => _shareWhatsApp(l10n, book, symbol, asOf),
      onExportCsv: () => _exportCsv(l10n, book, symbol, asOf),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final book = _book;
    final symbol = book != null
        ? Currency.symbolForCode(book.currencyCode)
        : 'SDG';
    final asOf = l10n.asOfDate(_dateFmt.format(_range.to));

    return ScreenAccessGate(
      screenType: AccountingScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.accounting),
          centerTitle: true,
          actions: [
            if (ReportExportMenu.canExport())
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: l10n.printOrShareReport,
                onPressed: book != null && book.entries.isNotEmpty
                    ? () => _openExportMenu(context, l10n, book, symbol, asOf)
                    : null,
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.incomeStatement),
              Tab(text: l10n.balanceSheet),
              Tab(text: l10n.trialBalance),
              Tab(text: l10n.chartOfAccounts),
            ],
          ),
        ),
        body: ResponsiveCenter(child: _body(context, l10n)),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    if (_failed) {
      return AppErrorState(message: l10n.operationFailed, onRetry: _load);
    }
    final book = _book;
    if (book == null) return const AppLoadingView();

    final symbol = Currency.symbolForCode(book.currencyCode);
    final entries = book.entries;
    final asOf = l10n.asOfDate(_dateFmt.format(_range.to));

    return Column(
      children: [
        ReportDateFilter(
          range: _range,
          onChanged: (r) {
            setState(() => _range = r);
            ReportsDateScope.update(context, r);
          },
        ),
        if (book.currencies.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.ledgerBaseCurrencyNotice(book.currencyCode),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: entries.isEmpty
              ? _EmptyBooks(message: l10n.noEntriesYet)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _IncomeStatementView(
                      statement: AccountingReports.incomeStatement(
                        entries,
                        from: _range.from,
                        to: _range.to,
                      ),
                      period: _range.label(l10n),
                      symbol: symbol,
                    ),
                    _BalanceSheetView(
                      sheet: AccountingReports.balanceSheet(
                        entries,
                        asOf: _range.to,
                      ),
                      asOf: asOf,
                      symbol: symbol,
                    ),
                    _TrialBalanceView(
                      trial: AccountingReports.trialBalance(
                        entries,
                        to: _range.to,
                      ),
                      asOf: asOf,
                      symbol: symbol,
                    ),
                    _AccountsView(
                      entries: entries,
                      range: _range,
                      asOf: asOf,
                      symbol: symbol,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyBooks extends StatelessWidget {
  final String message;
  const _EmptyBooks({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 64,
              color: scheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).accountingNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Building blocks ───────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final double? amount;
  final String? textValue;
  final bool bold;
  final bool divider;
  final Color? color;
  const _Row(
    this.label,
    this.amount, {
    this.textValue,
    this.bold = false,
    this.divider = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 15 : 14,
      color: color,
    );
    return Column(
      children: [
        if (divider) const Divider(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: style)),
              Text(
                textValue ?? (amount != null ? formatAmount(amount!) : '—'),
                style: style.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Highlighted single figure (net profit, grand totals, balances).
class _TotalCard extends StatelessWidget {
  final String label;
  final double? amount;
  final String? textValue;
  final Color? color;
  const _TotalCard(this.label, this.amount, {this.textValue, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: c.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _Row(label, amount, textValue: textValue, bold: true, color: c),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  final String symbol;
  final bool? balanced;
  const _Header(this.text, this.symbol, {this.balanced});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$text · $symbol',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          if (balanced != null)
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                balanced! ? Icons.check_circle : Icons.error_outline,
                size: 18,
                color: balanced!
                    ? AppStatusColors.fg(context, AppStatus.success)
                    : scheme.error,
              ),
              label: Text(
                balanced! ? l10n.balancedLabel : l10n.notBalancedLabel,
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Income statement ─────────────────────────────────────────────────────

class _IncomeStatementView extends StatelessWidget {
  final IncomeStatement statement;
  final String period;
  final String symbol;
  const _IncomeStatementView({
    required this.statement,
    required this.period,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = statement;
    final profit = s.netProfit >= 0;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Header(period, symbol),
        _Section(
          title: l10n.revenueSection,
          children: [
            _Row(l10n.accountName(Accounts.salesRevenue.code), s.salesRevenue),
            _Row(l10n.accountName(Accounts.cogs.code), -s.costOfSales),
            _Row(
              l10n.grossProfit,
              s.trustedGrossProfit,
              textValue: s.hasIncompleteCostOfSales ? '—' : null,
              bold: true,
              divider: true,
              color: (s.trustedGrossProfit != null && s.trustedGrossProfit! < 0)
                  ? scheme.error
                  : null,
            ),
            _Row(l10n.accountName(Accounts.otherIncome.code), s.otherIncome),
          ],
        ),
        _Section(
          title: l10n.expensesSection,
          children: [
            _Row(
              l10n.accountName(Accounts.operatingExpenses.code),
              s.operatingExpenses,
            ),
            _Row(
              l10n.accountName(Accounts.inventoryAdjustments.code),
              s.inventoryAdjustments,
            ),
            _Row(
              l10n.total,
              s.operatingExpenses + s.inventoryAdjustments,
              bold: true,
              divider: true,
            ),
          ],
        ),
        _TotalCard(
          s.hasIncompleteCostOfSales
              ? l10n.netProfit
              : (profit ? l10n.netProfit : l10n.netLoss),
          s.trustedNetProfit,
          textValue: s.hasIncompleteCostOfSales ? '—' : null,
          color: s.hasIncompleteCostOfSales
              ? AppStatusColors.fg(context, AppStatus.warning)
              : (profit
                    ? AppDesignTokens.semanticSuccess(context)
                    : scheme.error),
        ),
        const SizedBox(height: 12),
        if (s.hasIncompleteCostOfSales)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppStatusColors.bg(context, AppStatus.warning),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppStatusColors.border(context, AppStatus.warning),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppStatusColors.fg(context, AppStatus.warning),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${l10n.costIncomplete} (${s.uncostedSalesCount})',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppStatusColors.fg(context, AppStatus.warning),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text(
          l10n.accountingNote,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─── Balance sheet ────────────────────────────────────────────────────────

class _BalanceSheetView extends StatelessWidget {
  final BalanceSheet sheet;
  final String asOf;
  final String symbol;
  const _BalanceSheetView({
    required this.sheet,
    required this.asOf,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final b = sheet;
    List<Widget> rows(Map<Account, double> m) => [
      for (final e in m.entries)
        if (e.value.abs() >= 0.005) _Row(l10n.accountName(e.key.code), e.value),
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Header(asOf, symbol, balanced: b.isBalanced),
        _Section(
          title: l10n.assetsSection,
          children: [
            ...rows(b.assets),
            _Row(l10n.totalAssets, b.totalAssets, bold: true, divider: true),
          ],
        ),
        _Section(
          title: l10n.liabilitiesSection,
          children: [
            ...rows(b.liabilities),
            _Row(l10n.total, b.totalLiabilities, bold: true, divider: true),
          ],
        ),
        _Section(
          title: l10n.equitySection,
          children: [
            ...rows(b.equity),
            _Row(l10n.retainedEarnings, b.retainedEarnings),
            _Row(l10n.total, b.totalEquity, bold: true, divider: true),
          ],
        ),
        _TotalCard(
          l10n.totalLiabilitiesEquity,
          b.totalLiabilities + b.totalEquity,
        ),
      ],
    );
  }
}

// ─── Trial balance ────────────────────────────────────────────────────────

class _TrialBalanceView extends StatelessWidget {
  final TrialBalance trial;
  final String asOf;
  final String symbol;
  const _TrialBalanceView({
    required this.trial,
    required this.asOf,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Net balance of each account on its debit or credit side.
    final rows = [
      for (final r in trial.rows)
        if ((r.debit - r.credit).abs() >= 0.005)
          (r.account, r.debit - r.credit),
    ];
    final totalDebit = rows.fold(0.0, (s, r) => r.$2 > 0 ? s + r.$2 : s);
    final totalCredit = rows.fold(0.0, (s, r) => r.$2 < 0 ? s - r.$2 : s);
    const numStyle = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    final bold = numStyle.copyWith(fontWeight: FontWeight.bold);

    Widget line(
      String code,
      String name,
      String debit,
      String credit, {
      TextStyle style = numStyle,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(code, style: style)),
          Expanded(child: Text(name, style: style)),
          SizedBox(
            width: 96,
            child: Text(debit, style: style, textAlign: TextAlign.end),
          ),
          SizedBox(
            width: 96,
            child: Text(credit, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Header(asOf, symbol, balanced: trial.isBalanced),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 48,
                ),
                child: SizedBox(
                  width: 440,
                  child: Column(
                    children: [
                      line(
                        l10n.accountCode,
                        l10n.accountColumn,
                        l10n.debit,
                        l10n.credit,
                        style: bold.copyWith(color: scheme.primary),
                      ),
                      const Divider(height: 1),
                      for (final r in rows)
                        line(
                          r.$1.code,
                          l10n.accountName(r.$1.code),
                          r.$2 > 0 ? formatAmount(r.$2) : '',
                          r.$2 < 0 ? formatAmount(-r.$2) : '',
                        ),
                      const Divider(height: 1),
                      line(
                        '',
                        l10n.total,
                        formatAmount(totalDebit),
                        formatAmount(totalCredit),
                        style: bold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Accounts & ledger ────────────────────────────────────────────────────

class _AccountsView extends StatelessWidget {
  final List<JournalEntry> entries;
  final DateRangeFilter range;
  final String asOf;
  final String symbol;
  const _AccountsView({
    required this.entries,
    required this.range,
    required this.asOf,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final trial = AccountingReports.trialBalance(entries, to: range.to);
    final balances = {for (final r in trial.rows) r.account: r.balance};
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Header(asOf, symbol),
        for (final a in Accounts.all)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: ListTile(
              leading: Text(
                a.code,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: Text(l10n.accountName(a.code)),
              trailing: Text(
                formatAmount(balances[a] ?? 0),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountLedgerScreen(
                    entries: entries,
                    account: a,
                    range: range,
                    symbol: symbol,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ledger of one account for a period: opening balance, movements with a
/// running balance, closing balance. Tapping a line shows the full entry.
class AccountLedgerScreen extends StatelessWidget {
  final List<JournalEntry> entries;
  final Account account;
  final DateRangeFilter range;
  final String symbol;

  const AccountLedgerScreen({
    super.key,
    required this.entries,
    required this.account,
    required this.range,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final gl = AccountingReports.generalLedger(
      entries,
      account,
      from: range.from,
      to: range.to,
    );
    return ScreenAccessGate(
      screenType: AccountLedgerScreen,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.accountName(account.code)),
          centerTitle: true,
          actions: [
            if (ReportExportMenu.canExport())
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: l10n.printOrShareReport,
                onPressed: gl.lines.isNotEmpty
                    ? () => _openExportMenu(context, l10n, gl)
                    : null,
              ),
          ],
        ),
        body: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _Header(
                '${l10n.accountStatement} · ${range.label(l10n)}',
                symbol,
              ),
              _TotalCard(l10n.openingBalance, gl.openingBalance),
              if (gl.lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.noDataForPeriod,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              for (final line in gl.lines)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: ListTile(
                    onTap: () => _showEntry(context, line.entry),
                    title: Text(
                      '${entrySourceLabel(line.entry.source, l10n)} · ${line.entry.reference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_dateFmt.format(line.entry.date)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          line.debit > 0
                              ? '${l10n.debit} ${formatAmount(line.debit)}'
                              : '${l10n.credit} ${formatAmount(line.credit)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: line.debit > 0
                                ? AppDesignTokens.semanticSuccess(context)
                                : AppDesignTokens.semanticWarning(context),
                          ),
                        ),
                        Text(
                          formatAmount(line.runningBalance),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              _TotalCard(l10n.closingBalance, gl.closingBalance),
            ],
          ),
        ),
      ),
    );
  }

  PdfReportData _buildPdfData(AppLocalizations l10n, GeneralLedger gl) {
    return PdfReportData(
      title:
          '${l10n.accountStatement} - ${l10n.accountName(account.code)} (${account.code})',
      dateRange: range.label(l10n),
      summaryCards: [
        PdfReportSummaryCard(
          label: l10n.openingBalance,
          value: '${formatAmount(gl.openingBalance)} $symbol',
        ),
        PdfReportSummaryCard(
          label: l10n.closingBalance,
          value: '${formatAmount(gl.closingBalance)} $symbol',
        ),
      ],
      columns: [
        PdfReportColumn(title: l10n.date, flex: 1.2),
        PdfReportColumn(title: l10n.documentNumber, flex: 1.8),
        PdfReportColumn(
          title: l10n.debit,
          flex: 1.3,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.credit,
          flex: 1.3,
          align: pw.TextAlign.right,
        ),
        PdfReportColumn(
          title: l10n.accountBalance,
          flex: 1.5,
          align: pw.TextAlign.right,
        ),
      ],
      rows: gl.lines
          .map(
            (l) => [
              _dateFmt.format(l.entry.date),
              '${entrySourceLabel(l.entry.source, l10n)} ${l.entry.reference}',
              l.debit > 0 ? formatAmount(l.debit) : '—',
              l.credit > 0 ? formatAmount(l.credit) : '—',
              formatAmount(l.runningBalance),
            ],
          )
          .toList(),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    AppLocalizations l10n,
    GeneralLedger gl, {
    required bool isShare,
  }) async {
    final business = await DatabaseHelper.instance.getFirstBusiness();
    if (business == null) return;
    final data = _buildPdfData(l10n, gl);
    try {
      if (isShare) {
        await PdfService.shareReportPdf(
          business: business,
          l10n: l10n,
          data: data,
        );
      } else {
        await PdfService.printOrShareReportPdf(
          business: business,
          l10n: l10n,
          data: data,
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          l10n.operationFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _shareWhatsApp(AppLocalizations l10n, GeneralLedger gl) async {
    final text =
        '${l10n.accountStatement} - ${l10n.accountName(account.code)} (${account.code})\n'
        '${range.label(l10n)}\n'
        '${l10n.openingBalance}: ${formatAmount(gl.openingBalance)} $symbol\n'
        '${l10n.closingBalance}: ${formatAmount(gl.closingBalance)} $symbol';
    await PdfService.shareText(text: text);
  }

  Future<void> _exportCsv(
    BuildContext context,
    AppLocalizations l10n,
    GeneralLedger gl,
  ) async {
    final headers = [
      l10n.date,
      l10n.documentNumber,
      l10n.debit,
      l10n.credit,
      l10n.accountBalance,
    ];
    final csvRows = gl.lines
        .map(
          (l) => [
            l.entry.date,
            '${entrySourceLabel(l.entry.source, l10n)} ${l.entry.reference}',
            l.debit,
            l.credit,
            l.runningBalance,
          ],
        )
        .toList();
    try {
      final bytes = CsvService.instance.exportReportToCsv(
        headers: headers,
        rows: csvRows,
      );
      await PdfService.shareCsv(
        bytes: bytes,
        fileName:
            'ledger_${account.code}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          l10n.operationFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  void _openExportMenu(
    BuildContext context,
    AppLocalizations l10n,
    GeneralLedger gl,
  ) {
    ReportExportMenu.show(
      context: context,
      title: '${l10n.accountStatement} - ${l10n.accountName(account.code)}',
      onPrintPdf: () => _exportPdf(context, l10n, gl, isShare: false),
      onSharePdf: () => _exportPdf(context, l10n, gl, isShare: true),
      onShareWhatsApp: () => _shareWhatsApp(l10n, gl),
      onExportCsv: () => _exportCsv(context, l10n, gl),
    );
  }

  void _showEntry(BuildContext context, JournalEntry entry) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${l10n.journalEntry} · ${entrySourceLabel(entry.source, l10n)} · ${entry.reference}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_dateFmt.format(entry.date)),
              const Divider(),
              for (final l in entry.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l.account.code} ${l10n.accountName(l.account.code)}',
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          l.debit > 0 ? formatAmount(l.debit) : '',
                          textAlign: TextAlign.end,
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          l.credit > 0 ? formatAmount(l.credit) : '',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.total,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      formatAmount(entry.totalDebit),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      formatAmount(entry.totalCredit),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
