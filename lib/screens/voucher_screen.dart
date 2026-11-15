import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../services/document_service.dart';
import '../models/currency.dart';
import '../models/payment_method.dart';
import '../utils/date_format_utils.dart';
import '../utils/money_utils.dart';
import '../utils/error_utils.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/contact_autocomplete_field.dart';
import 'document_detail_screen.dart';
import '../widgets/responsive.dart';
import '../utils/number_input.dart';
import '../widgets/amount_field.dart';
import '../widgets/app_date_picker.dart';

enum VoucherType { paymentReceipt, expenseVoucher }

class VoucherScreen extends StatefulWidget {
  final VoucherType type;
  const VoucherScreen({super.key, required this.type});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime _voucherDate = DateTime.now();
  String _paymentMethod = 'cash';
  List<PaymentMethod> _enabledMethods = [];
  Business? _business;
  Contact? _selectedContact;
  String? _contactName;
  bool _saving = false;

  int _balanceQuerySeq = 0;
  bool _isLoadingBalance = false;
  double? _outstandingBalance;
  String? _balanceError;

  bool get isReceipt => widget.type == VoucherType.paymentReceipt;

  bool get _isDirty =>
      _selectedContact != null ||
      _amountController.text.isNotEmpty ||
      _reasonController.text.isNotEmpty;

  Future<bool> _onWillPop() async {
    if (!_isDirty || _saving) return true;
    final l10n = AppLocalizations.of(context);
    return AppConfirmDialog.show(
      context,
      title: l10n.unsavedChangesTitle,
      message: l10n.unsavedChangesMessage,
      confirmLabel: l10n.discardChanges,
      isDestructive: true,
    );
  }

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadBusiness();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    final business = await DatabaseHelper.instance.getFirstBusiness();
    final methods = await DatabaseHelper.instance.getEnabledPaymentMethods();
    if (!mounted) return;
    setState(() {
      _business = business;
      _enabledMethods = methods;
      if (!methods.any((m) => m.key == _paymentMethod)) {
        _paymentMethod = methods.isNotEmpty ? methods.first.key : 'cash';
      }
    });
    if (_selectedContact != null) {
      _fetchContactBalance(_selectedContact);
    }
  }

  String _formatAmount(double val, int decimals) {
    return NumberFormat.currency(
      symbol: '',
      decimalDigits: decimals,
    ).format(val).trim();
  }

  void _fetchContactBalance(Contact? contact) {
    if (contact == null || contact.id == null) {
      setState(() {
        _outstandingBalance = null;
        _isLoadingBalance = false;
        _balanceError = null;
      });
      return;
    }

    final queryId = ++_balanceQuerySeq;
    setState(() {
      _isLoadingBalance = true;
      _outstandingBalance = null;
      _balanceError = null;
    });

    final targetType = isReceipt ? 'invoice' : 'purchase';

    DatabaseHelper.instance
        .getOpenDocumentsForContact(contact.id!, targetType)
        .then((openDocs) {
          if (!mounted || queryId != _balanceQuerySeq) return;
          final currency = _business?.currencyCode ?? 'SDG';
          final decimals = Currency.decimalDigitsForCode(currency);
          double total = 0.0;
          for (final d in openDocs) {
            final rem =
                (d['remaining'] as num?)?.toDouble() ??
                ((d['total'] as num).toDouble() -
                    (d['paid'] as num).toDouble());
            total = MoneyUtils.round(total + rem, decimals);
          }
          setState(() {
            _outstandingBalance = total;
            _isLoadingBalance = false;
          });
        })
        .catchError((err) {
          if (!mounted || queryId != _balanceQuerySeq) return;
          setState(() {
            _balanceError = err.toString();
            _isLoadingBalance = false;
          });
        });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_business == null) return;

    final l10n = AppLocalizations.of(context);
    final amount = NumberInput.parse(_amountController.text) ?? 0;
    if (amount <= 0) {
      AppSnackBar.show(
        context,
        l10n.invalidAmount,
        severity: AppSnackBarSeverity.error,
      );
      return;
    }

    final rawName = _contactName?.trim() ?? '';
    final hasSelectedContact = _selectedContact?.id != null;
    final hasTypedNameOnly = !hasSelectedContact && rawName.isNotEmpty;

    if (hasTypedNameOnly && isReceipt) {
      AppSnackBar.show(
        context,
        l10n.voucherNoOpenDocuments,
        severity: AppSnackBarSeverity.error,
      );
      return;
    }

    if (hasSelectedContact) {
      if (_outstandingBalance != null && _outstandingBalance! <= 0) {
        AppSnackBar.show(
          context,
          l10n.voucherNoOpenDocuments,
          severity: AppSnackBarSeverity.error,
        );
        return;
      }
      final currency = _business?.currencyCode ?? 'SDG';
      final decimalDigits = Currency.decimalDigitsForCode(currency);
      final sym = Currency.symbolForCode(currency);
      if (_outstandingBalance != null &&
          MoneyUtils.round(amount - _outstandingBalance!, decimalDigits) > 0) {
        final formatted =
            '${_formatAmount(_outstandingBalance!, decimalDigits)} $sym';
        AppSnackBar.show(
          context,
          l10n.voucherAmountExceedsOutstanding(formatted),
          severity: AppSnackBarSeverity.error,
        );
        return;
      }
    }

    setState(() => _saving = true);

    if (!_enabledMethods.any((m) => m.key == _paymentMethod)) {
      _paymentMethod = _enabledMethods.isNotEmpty
          ? _enabledMethods.first.key
          : 'cash';
    }

    try {
      if (hasSelectedContact) {
        final receiptIds = await DocumentService.recordFifoPayment(
          contactId: _selectedContact!.id!,
          isCustomer: isReceipt,
          amount: amount,
          paymentMethod: _paymentMethod,
          notes: _reasonController.text.trim(),
        );
        if (!mounted) return;
        if (receiptIds.length == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DocumentDetailScreen(documentId: receiptIds.first),
            ),
          );
        } else {
          AppSnackBar.show(
            context,
            l10n.voucherAllocatedSnack(receiptIds.length.toString()),
            severity: AppSnackBarSeverity.success,
          );
          Navigator.pop(context);
        }
      } else {
        String effectiveNotes = _reasonController.text.trim();
        if (hasTypedNameOnly) {
          final prefix = '${l10n.paidTo}: $rawName';
          effectiveNotes = effectiveNotes.isEmpty
              ? prefix
              : '$prefix\n$effectiveNotes';
        }
        final docId = await DocumentService.createDocument(
          type: isReceipt ? 'payment_receipt' : 'expense_voucher',
          business: _business!,
          contact: null,
          recipientName: hasTypedNameOnly ? rawName : null,
          items: const [],
          paid: amount,
          notes: effectiveNotes,
          date: _voucherDate,
          paymentMethod: _paymentMethod,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(documentId: docId),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final friendly = ErrorUtils.toFriendlyMessage(e, l10n);
      AppSnackBar.show(context, friendly, severity: AppSnackBarSeverity.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildBalancePreview(AppLocalizations l10n) {
    if (_selectedContact == null) {
      final typed = (_contactName ?? '').trim().isNotEmpty;
      if (!(isReceipt && typed)) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.voucherSelectCustomerHint,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final currency = _business?.currencyCode ?? 'SDG';
    final sym = Currency.symbolForCode(currency);
    final decimalDigits = Currency.decimalDigitsForCode(currency);

    Widget content;
    if (_isLoadingBalance) {
      content = Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.voucherLoadingBalance,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      );
    } else if (_balanceError != null) {
      content = Text(
        l10n.voucherBalanceLoadFailed,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      final balance = _outstandingBalance ?? 0.0;
      final formattedBal = '${_formatAmount(balance, decimalDigits)} $sym';
      final isZero = balance <= 0.0;

      final label = isReceipt
          ? l10n.voucherOutstandingCustomer(formattedBal)
          : l10n.voucherOutstandingSupplier(formattedBal);

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isZero
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (!isZero)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: Text(l10n.voucherPayFullBalance),
                  onPressed: () {
                    setState(() {
                      _amountController.text = NumberInput.formatForInput(
                        balance,
                        maxDecimals: 4,
                      );
                    });
                  },
                ),
            ],
          ),
          if (isZero) ...[
            const SizedBox(height: 4),
            Text(
              l10n.voucherNoOpenDocuments,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: content,
    );
  }

  Widget _sectionCard(Widget child) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
      ),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isReceipt = this.isReceipt;
    final title = isReceipt ? l10n.paymentReceipt : l10n.expenseVoucher;
    final contactLabel = isReceipt ? l10n.receivedFrom : l10n.paidTo;
    final contactType = isReceipt ? 'customer' : 'supplier';
    final contactHint = isReceipt ? l10n.customer : l10n.supplier;

    final allowedMethods = _enabledMethods;

    return PopScope(
      canPop: !_isDirty || _saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final proceed = await _onWillPop();
        if (proceed && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title), centerTitle: true),
        body: ResponsiveCenter(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsetsDirectional.all(16),
              children: [
                _sectionCard(
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(l10n.date),
                    subtitle: Text(
                      AppDateUtils.formatDate(_voucherDate),
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final picked = await AppDatePicker.show(
                        context: context,
                        initialDate: _voucherDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _voucherDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contactLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ContactAutocompleteField(
                          label: contactHint,
                          type: contactType,
                          onContactChanged: (contact) {
                            setState(() {
                              _selectedContact = contact;
                              _contactName = contact?.name;
                            });
                            _fetchContactBalance(contact);
                          },
                          onTextChanged: (value) {
                            setState(() {
                              _contactName = value;
                              if (_selectedContact?.name != value) {
                                _selectedContact = null;
                                _outstandingBalance = null;
                                _isLoadingBalance = false;
                              }
                            });
                          },
                        ),
                        _buildBalancePreview(l10n),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.amount,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AmountField(
                          controller: _amountController,
                          maxDecimals: 4,
                          showMultipliers: true,
                          decoration: InputDecoration(
                            labelText: l10n.amount,
                            prefixIcon: const Icon(Icons.money),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            final amount = NumberInput.parse(v ?? '');
                            if (amount == null || amount <= 0) {
                              return l10n.invalidAmount;
                            }
                            if (_selectedContact != null &&
                                _outstandingBalance != null) {
                              final currency = _business?.currencyCode ?? 'SDG';
                              final decimalDigits =
                                  Currency.decimalDigitsForCode(currency);
                              final sym = Currency.symbolForCode(currency);
                              final roundedAmount = MoneyUtils.round(
                                amount,
                                decimalDigits,
                              );
                              final roundedBal = MoneyUtils.round(
                                _outstandingBalance!,
                                decimalDigits,
                              );
                              if (MoneyUtils.round(
                                    roundedAmount - roundedBal,
                                    decimalDigits,
                                  ) >
                                  0) {
                                final formatted =
                                    '${_formatAmount(roundedBal, decimalDigits)} $sym';
                                return l10n.voucherAmountExceedsOutstanding(
                                  formatted,
                                );
                              }
                            }
                            return null;
                          },
                        ),
                        if (_selectedContact != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            isReceipt
                                ? l10n.voucherAllocationHintCustomer
                                : l10n.voucherAllocationHintSupplier,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.paymentMethod,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: allowedMethods.map((method) {
                            return _paymentChip(
                              method.key,
                              method.label(l10n.langCode),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.reason,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (!isReceipt) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                label: Text(l10n.expenseRent),
                                onPressed: () => setState(
                                  () =>
                                      _reasonController.text = l10n.expenseRent,
                                ),
                              ),
                              ActionChip(
                                label: Text(l10n.expenseElectricity),
                                onPressed: () => setState(
                                  () => _reasonController.text =
                                      l10n.expenseElectricity,
                                ),
                              ),
                              ActionChip(
                                label: Text(l10n.expenseSalaries),
                                onPressed: () => setState(
                                  () => _reasonController.text =
                                      l10n.expenseSalaries,
                                ),
                              ),
                              ActionChip(
                                label: Text(l10n.expenseTransport),
                                onPressed: () => setState(
                                  () => _reasonController.text =
                                      l10n.expenseTransport,
                                ),
                              ),
                              ActionChip(
                                label: Text(l10n.expenseMaintenance),
                                onPressed: () => setState(
                                  () => _reasonController.text =
                                      l10n.expenseMaintenance,
                                ),
                              ),
                              ActionChip(
                                label: Text(l10n.expenseOther),
                                onPressed: () => setState(
                                  () => _reasonController.text =
                                      l10n.expenseOther,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: l10n.reason,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed:
                        (_saving ||
                            (_selectedContact != null &&
                                _outstandingBalance != null &&
                                _outstandingBalance! <= 0))
                        ? null
                        : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDesignTokens.buttonRadius,
                        ),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Text(l10n.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _paymentMethod == value,
      onSelected: (selected) {
        if (selected) setState(() => _paymentMethod = value);
      },
      selectedColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.15),
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: _paymentMethod == value
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _paymentMethod == value
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}
