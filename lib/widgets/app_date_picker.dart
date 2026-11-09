import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../utils/date_format_utils.dart';

/// Centralized Date Picker helper that guarantees:
/// 1. Arabic month names, days, and action labels.
/// 2. Strict Western numerals (0-9) inside the calendar grids and headers.
/// 3. Proper RTL directionality for Arabic text.
class AppDatePicker {
  AppDatePicker._();

  /// Default starting boundary for business dates.
  static final DateTime defaultFirstDate = DateTime(2000, 1, 1);

  /// Default ending boundary for business dates.
  static final DateTime defaultLastDate = DateTime(2100, 12, 31);

  /// Shows the standard single-date picker with Arabic labels and Western numerals.
  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final effectiveFirst = firstDate ?? defaultFirstDate;
    final effectiveLast = lastDate ?? defaultLastDate;

    // Clamp initialDate within bounds
    var safeInitial = initialDate;
    if (safeInitial.isBefore(effectiveFirst)) safeInitial = effectiveFirst;
    if (safeInitial.isAfter(effectiveLast)) safeInitial = effectiveLast;

    return showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: effectiveFirst,
      lastDate: effectiveLast,
      // 'ar_DZ' locale retains Arabic localized text but enforces Western Arabic (0-9) digits.
      locale: const Locale('ar', 'DZ'),
      builder: (ctx, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// Shows the standard date range picker with Arabic labels and Western numerals.
  static Future<DateTimeRange?> showRange({
    required BuildContext context,
    DateTimeRange? initialDateRange,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final effectiveFirst = firstDate ?? defaultFirstDate;
    final effectiveLast = lastDate ?? defaultLastDate;

    return showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: effectiveFirst,
      lastDate: effectiveLast,
      // 'ar_DZ' locale retains Arabic localized text but enforces Western Arabic (0-9) digits.
      locale: const Locale('ar', 'DZ'),
      builder: (ctx, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// A specialized, self-contained date text input field with calendar picker integration.
///
/// Features:
/// - Western 0-9 digits display and normalization from Arabic/Persian digits.
/// - Auto-inserts '/' while typing.
/// - Calendar picker button in suffix.
/// - Clear Arabic validation message on invalid real dates.
/// - LTR-safe text direction for the date digits.
class AppDateInputField extends StatefulWidget {
  final String? label;
  final String? hintText;
  final DateTime? initialDate;
  final ValueChanged<DateTime?>? onDateChanged;
  final FormFieldValidator<String>? customValidator;
  final TextEditingController? controller;
  final bool isRequired;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  const AppDateInputField({
    super.key,
    this.label,
    this.hintText,
    this.initialDate,
    this.onDateChanged,
    this.customValidator,
    this.controller,
    this.isRequired = false,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  @override
  State<AppDateInputField> createState() => _AppDateInputFieldState();
}

class _AppDateInputFieldState extends State<AppDateInputField> {
  late TextEditingController _effectiveController;
  bool _internalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _effectiveController = widget.controller!;
    } else {
      _internalController = true;
      _effectiveController = TextEditingController(
        text: widget.initialDate != null
            ? AppDateUtils.formatDate(widget.initialDate!)
            : '',
      );
    }
  }

  @override
  void didUpdateWidget(covariant AppDateInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_internalController) {
        _effectiveController.dispose();
        _internalController = false;
      }
      if (widget.controller != null) {
        _effectiveController = widget.controller!;
      } else {
        _internalController = true;
        _effectiveController = TextEditingController(
          text: widget.initialDate != null
              ? AppDateUtils.formatDate(widget.initialDate!)
              : '',
        );
      }
    } else if (_internalController &&
        widget.initialDate != oldWidget.initialDate &&
        widget.initialDate != null) {
      _effectiveController.text = AppDateUtils.formatDate(widget.initialDate!);
    }
  }

  @override
  void dispose() {
    if (_internalController) {
      _effectiveController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (!widget.enabled) return;
    final currentParsed = AppDateUtils.parseDate(_effectiveController.text);
    final picked = await AppDatePicker.show(
      context: context,
      initialDate: currentParsed ?? widget.initialDate ?? DateTime.now(),
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked != null && mounted) {
      final formatted = AppDateUtils.formatDate(picked);
      _effectiveController.text = formatted;
      widget.onDateChanged?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectiveLabel = widget.label ?? l10n.selectDate;

    return Directionality(
      textDirection: Directionality.of(context),
      child: TextFormField(
        controller: _effectiveController,
        enabled: widget.enabled,
        keyboardType: TextInputType.datetime,
        textDirection: TextDirection.ltr,
        inputFormatters: const [
          DateTextInputFormatter(),
        ],
        decoration: InputDecoration(
          labelText: effectiveLabel,
          hintText: widget.hintText ?? 'YYYY/MM/DD',
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: l10n.selectDate,
            onPressed: widget.enabled ? _pickDate : null,
          ),
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (widget.isRequired && (value == null || value.trim().isEmpty)) {
            return l10n.invalidDate;
          }
          final dateErr = AppDateUtils.validateDate(
            value,
            l10n: l10n,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
          );
          if (dateErr != null) return dateErr;
          return widget.customValidator?.call(value);
        },
        onChanged: (val) {
          final parsed = AppDateUtils.parseDate(val);
          widget.onDateChanged?.call(parsed);
        },
      ),
    );
  }
}
