#!/usr/bin/env bash
#
# Play Payments compliance guard.
#
# Four independent passes:
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
#   3. URL-allowlist pass. On the reviewer-visible screens (About / License /
#      Transparency / Activation) plus the AppConstants file, every `http(s)://`
#      literal in a non-comment line must match the three-URL product-site
#      allowlist or the activation API host. Any other URL — a WhatsApp link,
#      a Facebook page, a product-pricing page — fails the build.
#
#   4. Forbidden-term pass. On the same five files, bare tokens that would
#      hint at acquisition / pricing (whatsapp, wa.me, facebook, pro.html,
#      pricing, +<digits>) must not appear in non-comment lines. Comment
#      lines are ignored so docstrings may describe what the file does NOT
#      do (e.g. "No pricing, no WhatsApp") without tripping the guard.
#
# Exit code 0 means the code is clean. Non-zero means a forbidden token or
# an un-allowlisted URL was found; the offending lines are printed so a
# reviewer can fix them.

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
# it. The About screen is covered by Pass 3 / Pass 4 below.
ACQUISITION_PATTERN='contact us|contacting us|through our website|on whatsapp|wa\.me|https?://|تواصل معنا|التواصل معنا|راسلنا|اتصل بنا|موقعنا|من خلال موقع|عبر واتساب'

# Pro-gating files scanned in the acquisition pass. Keep this list tight so
# the pass stays targeted at user-visible activation copy.
ACQUISITION_SCAN=(
  "lib/screens/locked_feature_screen.dart"
  "lib/screens/activation_screen.dart"
  "lib/screens/license_screen.dart"
  "lib/screens/transparency_screen.dart"
  "lib/widgets/pro_upgrade_sheet.dart"
  "lib/localization/app_localizations.dart"
)

# Reviewer-visible screens + the constants file that drives their outbound
# links. Every URL here must be in the allowlist and no acquisition-leak
# term may appear in non-comment lines.
REVIEWER_VISIBLE=(
  "lib/core/constants/app_constants.dart"
  "lib/screens/about_screen.dart"
  "lib/screens/license_screen.dart"
  "lib/screens/transparency_screen.dart"
  "lib/screens/activation_screen.dart"
)

# Support surface: the only files allowed to reference the support channels
# (WhatsApp / Facebook / website / Play listing). They are still URL-
# allowlisted and still scanned for price / pricing-page tokens.
SUPPORT_SURFACE=(
  "lib/core/constants/app_constants.dart"
  "lib/screens/about_screen.dart"
)

# The ONLY outbound hosts the app is permitted to reach. Three product-site
# pages (privacy, terms, delete-data) plus the activation API host.
URL_ALLOWLIST_RE='^(https://almhdy24\.com/products/waraqatak/(privacy|terms|delete)\.html|https://api\.almhdy24\.com(/.*)?)$'

# Support links, allowed on SUPPORT_SURFACE files only.
SUPPORT_URL_RE='^(https://wa\.me/249993452125|https://www\.facebook\.com/profile\.php\?id=61593843478292|https://almhdy24\.com|https://play\.google\.com/store/apps/details\?id=com\.elmahdi\.waraqatak)$'

# Hard-forbidden tokens on reviewer-visible screens, case-insensitive,
# matched against non-comment lines only. The guard-script path and
# Dart comments that *describe absence* ("No WhatsApp, no Facebook") are
# intentionally not flagged — the pass sees string literals and code
# identifiers, not docstrings.
LEAK_PATTERN='whatsapp|wa\.me|facebook|pro\.html|pricing|\+[0-9]{3,}'
# On the support surface, support-channel names are expected; prices and
# pricing pages are still forbidden.
SUPPORT_LEAK_PATTERN='pro\.html|pricing|\+[0-9]{3,}'

is_support_surface() {
  local f
  for f in "${SUPPORT_SURFACE[@]}"; do
    [ "$f" = "$1" ] && return 0
  done
  return 1
}

# Files to scan in the purchase-vocabulary pass (Dart source only; tests
# and generated code are excluded).
mapfile -t FILES < <(find lib -type f -name '*.dart' 2>/dev/null | sort)

violations=0

# ──────────────────────────────────────────────────────────────────────────
# Pass 1 — purchase-vocabulary.
# ──────────────────────────────────────────────────────────────────────────
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

# ──────────────────────────────────────────────────────────────────────────
# Pass 2 — acquisition-copy.
# ──────────────────────────────────────────────────────────────────────────
#
# For the localization file we deliberately scope the scan to the Pro-gating
# getters so unrelated merchant-contact strings do not false-positive.
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
      -e 'get transparencyTitle ' \
      -e 'get transparencyIntro ' \
      -e 'get transparencyFreeHeader ' \
      -e 'get transparencyProHeader ' \
      -e 'get seeFreeVsPro ' \
      -e 'get featureInvoices ' \
      -e 'get featureQuotations ' \
      -e 'get featureVouchers ' \
      -e 'get featureCustomDocuments ' \
      -e 'get featureCustomers ' \
      -e 'get featureProducts ' \
      -e 'get featureBarcode ' \
      -e 'get featureBasicReports ' \
      -e 'get featureBackupRestore ' \
      -e 'get featurePurchases ' \
      -e 'get featureInventory ' \
      -e 'get featureAdvancedReports ' \
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

# ──────────────────────────────────────────────────────────────────────────
# Pass 3 — URL allowlist on reviewer-visible files.
# ──────────────────────────────────────────────────────────────────────────
#
# Strips comment-only lines (first non-whitespace char `/`) so that
# docstrings may freely mention URLs for explanatory purposes. On the
# remaining lines, extracts every `http(s)://…` run and compares it
# against the allowlist regex. Trailing punctuation `.,);]"` is trimmed
# before matching.
for file in "${REVIEWER_VISIBLE[@]}"; do
  [ -f "$file" ] || continue
  # Numbered, comment-stripped stream.
  while IFS= read -r raw; do
    lineno="${raw%%:*}"
    content="${raw#*:}"
    for url in $(printf '%s\n' "$content" \
                   | grep -oE 'https?://[A-Za-z0-9._~:/?#@!$&()*+,;=%\-]+' \
                   || true); do
      # Trim trailing non-URL punctuation.
      clean=$(printf '%s' "$url" | sed -E 's/[.,);\]"'"'"']+$//')
      if is_support_surface "$file" &&
         printf '%s' "$clean" | grep -qE "$SUPPORT_URL_RE"; then
        continue
      fi
      if ! printf '%s' "$clean" | grep -qE "$URL_ALLOWLIST_RE"; then
        echo "FAIL [url-allowlist]: $file:$lineno $clean"
        violations=$((violations + 1))
      fi
    done
  done < <(awk '!/^[[:space:]]*\/\//{print NR":"$0}' "$file")
done

# ──────────────────────────────────────────────────────────────────────────
# Pass 4 — forbidden-term scan on reviewer-visible files.
# ──────────────────────────────────────────────────────────────────────────
#
# Comment-stripped; preserves original line numbers via awk's NR prefix.
for file in "${REVIEWER_VISIBLE[@]}"; do
  [ -f "$file" ] || continue
  pattern="$LEAK_PATTERN"
  is_support_surface "$file" && pattern="$SUPPORT_LEAK_PATTERN"
  if matches=$(awk '!/^[[:space:]]*\/\//{print NR":"$0}' "$file" \
               | grep -Ei "$pattern"); then
    echo "FAIL [leak]: $file"
    echo "$matches" | sed 's/^/    /'
    violations=$((violations + 1))
  fi
done

if [ "$violations" -gt 0 ]; then
  echo
  echo "Play compliance guard failed: $violations violation(s)."
  echo "- [purchase]     in-app purchase / subscription language. Either"
  echo "                 remove it or, if it is part of the merchant's own"
  echo "                 invoicing feature, add the file to WHITELIST_PATHS."
  echo "- [acquisition]  describes where/how to obtain the activation key."
  echo "                 Remove website, WhatsApp, phone, or 'contact us' hints."
  echo "- [url-allowlist] URL on a reviewer-visible screen is not one of the"
  echo "                 three product-site pages or the activation API host."
  echo "- [leak]         a bare acquisition token (whatsapp / wa.me / facebook /"
  echo "                 pro.html / pricing / +<digits>) appears on a"
  echo "                 reviewer-visible screen outside a comment."
  exit 1
fi

echo "Play compliance guard: OK"
exit 0
