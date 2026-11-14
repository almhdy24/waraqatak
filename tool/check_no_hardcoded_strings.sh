#!/usr/bin/env bash
set -e

DIRS="lib/services/access lib/screens/access lib/widgets/access"

echo "Checking for Arabic characters in access directories..."
if grep -rn -P '[\x{0600}-\x{06FF}]' $DIRS; then
  echo "ERROR: Hardcoded Arabic characters found in access code!"
  exit 1
fi

echo "Checking for 'isArabic ?' in access directories..."
if grep -rn 'isArabic\s*?' $DIRS; then
  echo "ERROR: 'isArabic ?' found in access code!"
  exit 1
fi

echo "Checking for raw e.toString() in access directories..."
if grep -rn -E '(showSnackBar|showDialog|Text\().*(e|error|err)\.toString\(\)' $DIRS; then
  echo "ERROR: Raw error.toString() found in UI!"
  exit 1
fi

echo "All checks passed! No hardcoded strings found in access code."
exit 0
