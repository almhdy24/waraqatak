#!/usr/bin/env bash
#
# Play Payments compliance guard.
#
# Scans the Dart source tree for user-facing strings that imply the app
# offers or facilitates purchases of digital goods (which would require
# Google Play Billing). Pro features in Waraqatak are activated via a
# key obtained OUTSIDE the app — nothing is bought or paid for in-app.
#
# A whitelist exempts the business owner's own invoicing feature:
# `payment_methods` (how the merchant records how their customers paid),
# `document_payments` (payment records against the merchant's invoices),
# and the related screens/models/reports. That is the merchant's bookkeeping
# feature and has nothing to do with purchasing anything inside the app.
#
# Exit code 0 means the code is clean. Non-zero means a forbidden term
# was found in a file that is NOT whitelisted; the offending lines are
# printed so a reviewer can fix them.

set -u

cd "$(dirname "$0")/.." || exit 2

# Files/paths that are allowed to contain payment vocabulary because they
# implement the merchant's own invoicing bookkeeping, not an in-app purchase.
WHITELIST_PATHS=(
  "lib/models/document_payment.dart"
  "lib/models/payment_method.dart"
  "lib/screens/payment_methods_screen.dart"
  "lib/screens/reports/payments_report_screen.dart"
  # Document/transaction screens record customer payments against invoices.
  "lib/screens/document_detail_screen.dart"
  "lib/screens/record_payment_screen.dart"
  "lib/screens/payment_history_screen.dart"
  "lib/screens/transactions_screen.dart"
  # Database owns the payment_methods / document_payments tables.
  "lib/database/database_helper.dart"
  # Localization intentionally defines merchant-facing payment strings
  # (recordPayment, paymentMethod, paymentHistory, etc.).
  "lib/localization/app_localizations.dart"
  # Backup service serializes the payment tables.
  "lib/services/backup_service.dart"
  # This script itself.
  "tool/check_play_compliance.sh"
)

is_whitelisted() {
  local path="$1"
  for allowed in "${WHITELIST_PATHS[@]}"; do
    if [ "$path" = "$allowed" ]; then
      return 0
    fi
  done
  return 1
}

# Terms that must NEVER appear in a non-whitelisted user-facing file.
# These are the English and Arabic forms of in-app-purchase / subscription
# language. The regex is case-insensitive; it matches identifiers too, so a
# UI string like "Buy Pro" OR a dangling `subscriptionPrice` getter both fail.
FORBIDDEN_PATTERN='buy pro|purchase pro|subscribe|subscription plan|checkout|price list|pay now|free trial then pay|اشتر|اشتراك شهري|سعر الاشتراك|ادفع الآن|إتمام الشراء'

# Files to scan (Dart source only; tests and generated code are excluded).
mapfile -t FILES < <(find lib -type f -name '*.dart' 2>/dev/null | sort)

violations=0
for file in "${FILES[@]}"; do
  rel="${file#./}"
  if is_whitelisted "$rel"; then
    continue
  fi
  if matches=$(grep -nEi "$FORBIDDEN_PATTERN" "$file"); then
    echo "FAIL: $rel"
    echo "$matches" | sed 's/^/    /'
    violations=$((violations + 1))
  fi
done

if [ "$violations" -gt 0 ]; then
  echo
  echo "Play compliance guard failed: $violations file(s) contain in-app"
  echo "purchase / subscription language that is not whitelisted."
  echo "Either remove the term or, if it is part of the merchant's own"
  echo "invoicing feature, add the file to WHITELIST_PATHS in this script."
  exit 1
fi

echo "Play compliance guard: OK"
exit 0
