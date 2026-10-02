#!/usr/bin/env bash
#
# Play Payments compliance guard.
#
# Two independent passes:
#
#   1. Purchase-vocabulary pass. Scans the Dart source tree for user-facing
#      strings that imply the app offers or facilitates purchases of digital
#      goods (which would require Google Play Billing). A whitelist exempts
#      the business owner's own invoicing bookkeeping.
#
#   2. Acquisition-copy pass. Pro features in Waraqatak are activated via a
#      key obtained OUTSIDE the app. The app itself must not describe WHERE
#      or HOW to obtain that key — no URLs, phone numbers, website / WhatsApp
#      hints, or "contact us" copy anywhere in the Pro-gating UI or in the
#      localization getters that back it.
#
# Exit code 0 means the code is clean. Non-zero means a forbidden term was
# found; the offending lines are printed so a reviewer can fix them.

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

# Phrases that describe where/how to obtain the activation key. These must
# not appear in the Pro-gating UI or in the localization getters that back
# it. The About screen is deliberately excluded — it is a company-info page
# that lists generic contact details, not Pro-gating acquisition copy.
ACQUISITION_PATTERN='contact us|contacting us|through our website|on whatsapp|wa\.me|https?://|تواصل معنا|التواصل معنا|راسلنا|اتصل بنا|موقعنا|من خلال موقع|عبر واتساب'

# Pro-gating files scanned in the acquisition pass. Keep this list tight so
# the pass stays targeted at user-visible activation copy.
ACQUISITION_SCAN=(
  "lib/screens/locked_feature_screen.dart"
  "lib/screens/activation_screen.dart"
  "lib/screens/license_screen.dart"
  "lib/widgets/pro_upgrade_sheet.dart"
  "lib/localization/app_localizations.dart"
)

# Files to scan in the purchase-vocabulary pass (Dart source only; tests
# and generated code are excluded).
mapfile -t FILES < <(find lib -type f -name '*.dart' 2>/dev/null | sort)

violations=0

# Pass 1 — purchase-vocabulary.
for file in "${FILES[@]}"; do
  rel="${file#./}"
  if is_whitelisted "$rel"; then
    continue
  fi
  if matches=$(grep -nEi "$FORBIDDEN_PATTERN" "$file"); then
    echo "FAIL [purchase]: $rel"
    echo "$matches" | sed 's/^/    /'
    violations=$((violations + 1))
  fi
done

# Pass 2 — acquisition-copy.
#
# For the localization file we deliberately scope the scan to the four
# Pro-gating getters so that unrelated merchant-contact strings (e.g. the
# About-screen `contactWhatsApp` label) do not false-positive.
scan_file_for_acquisition() {
  local file="$1"
  local body="$2"
  if matches=$(printf '%s' "$body" | grep -nEi "$ACQUISITION_PATTERN"); then
    echo "FAIL [acquisition]: $file"
    echo "$matches" | sed 's/^/    /'
    violations=$((violations + 1))
  fi
}

for target in "${ACQUISITION_SCAN[@]}"; do
  if [ ! -f "$target" ]; then
    continue
  fi
  if [ "$target" = "lib/localization/app_localizations.dart" ]; then
    # Extract only the Pro-gating getter bodies. Each getter is a single
    # line (sometimes continued over 2–3 lines until a `)` or `;` terminator);
    # we grab a 4-line window after each marker to capture multi-line bodies.
    body=$(grep -nE -A3 \
      -e 'get proFeaturesActivation ' \
      -e 'get getActivationKeyInfo ' \
      -e 'get invalidOrExpiredKey ' \
      -e 'get activationTooManyAttempts ' \
      -e 'get activationServerUnreachable ' \
      -e 'get licenseScreenTitle ' \
      -e 'get licenseStatusLabel ' \
      -e 'get licenseTypeLabel ' \
      -e 'get licenseExpiryLabel ' \
      -e 'get licenseTypeTrial ' \
      -e 'get licenseTypeActivated ' \
      -e 'get licenseNoExpiryDate ' \
      -e 'get licenseOnExpiryTitle ' \
      -e 'get licenseOnExpiryBody ' \
      -e 'get enterOrChangeKey ' \
      -e 'get removeKeyFromDevice ' \
      -e 'get removeKeyConfirmTitle ' \
      -e 'get removeKeyConfirmBody ' \
      -e 'get removeKeyConfirmAction ' \
      -e 'get keyRemovedSnack ' \
      -e 'get enterActivationKey ' \
      -e 'get enterActivationKeyAction ' \
      -e 'get activationKeyHint ' \
      -e 'get activate ' \
      -e 'get activationSuccessTitle ' \
      -e 'get activationSuccessBody ' \
      "$target")
  else
    body=$(cat "$target")
  fi
  scan_file_for_acquisition "$target" "$body"
done

if [ "$violations" -gt 0 ]; then
  echo
  echo "Play compliance guard failed: $violations violation(s)."
  echo "- [purchase] lines use in-app purchase / subscription language."
  echo "  Either remove the term or, if it is part of the merchant's own"
  echo "  invoicing feature, add the file to WHITELIST_PATHS."
  echo "- [acquisition] lines describe where/how to obtain the activation"
  echo "  key. The app must not direct the user to a website, WhatsApp,"
  echo "  phone number, or 'contact us' flow. Remove the wording."
  exit 1
fi

echo "Play compliance guard: OK"
exit 0
