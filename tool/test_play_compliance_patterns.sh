#!/usr/bin/env bash
# Checks the leak patterns of check_play_compliance.sh against known samples.
cd "$(dirname "$0")/.." || exit 2
eval "$(grep -E '^(LEAK_PATTERN|SUPPORT_LEAK_PATTERN)=' tool/check_play_compliance.sh)"
fail=0
ok()   { printf '%s\n' "$2" | grep -qEi "$1" && { echo "FAIL (should pass): $2"; fail=1; }; }
bad()  { printf '%s\n' "$2" | grep -qEi "$1" || { echo "FAIL (should flag): $2"; fail=1; }; }
for P in "$LEAK_PATTERN" "$SUPPORT_LEAK_PATTERN"; do
  ok  "$P" "Feature.wholesalePricing => l10n.featureWholesalePricing,"
  ok  "$P" "Feature.wholesalePricing: Icons.storefront_outlined,"
  bad "$P" "Text('Pricing page')"
  bad "$P" "const url = '/pricing';"
  bad "$P" "launch('https://x.com/pricing.html')"
  bad "$P" "label: 'pricing',"
  bad "$P" "Text('Pro pricing')"
  bad "$P" "Text('+249123456')"
  bad "$P" "href: 'pro.html'"
done
bad "$LEAK_PATTERN" "Text('whatsapp')"
bad "$LEAK_PATTERN" "url: 'https://wa.me/1'"
bad "$LEAK_PATTERN" "Text('Facebook')"
[ $fail -eq 0 ] && echo "patterns OK" || exit 1
