#!/usr/bin/env bash
# Resumable one-by-one test runner for Waraqatak (low-RAM / Termux safe)
# Discovers all unit/widget tests (excluding showcase and live tests)
# and runs each in isolation with a 900-second timeout.

set -u

RESULTS_DIR=".dart_tool"
RESULTS_FILE="$RESULTS_DIR/test_results.tsv"
mkdir -p "$RESULTS_DIR"

FRESH=false
for arg in "$@"; do
  if [[ "$arg" == "--fresh" ]]; then
    FRESH=true
  fi
done

if [[ "$FRESH" == true ]]; then
  rm -f "$RESULTS_FILE"
fi

touch "$RESULTS_FILE"

# Discover test files
mapfile -t ALL_TESTS < <(find test -name '*_test.dart' | grep -v "/showcase/" | grep -v "test_live" | sort)
TOTAL_DISCOVERED=${#ALL_TESTS[@]}

if [[ $TOTAL_DISCOVERED -eq 0 ]]; then
  echo "ERROR: No test files discovered under test/" >&2
  exit 1
fi

echo "=================================================="
echo "Waraqatak One-By-One Test Runner"
echo "Discovered $TOTAL_DISCOVERED test files"
echo "Results file: $RESULTS_FILE"
echo "Mode: $([[ "$FRESH" == true ]] && echo 'FRESH (all tests will run)' || echo 'RESUME (skipping prior PASS tests)')"
echo "=================================================="

# Read already passed files into an associative array
declare -A ALREADY_PASSED
while IFS=$'\t' read -r r_file r_status r_p r_f r_s; do
  if [[ "$r_status" == "PASS" ]]; then
    ALREADY_PASSED["$r_file"]=1
  fi
done < "$RESULTS_FILE"

RUN_TMP_LOG="$RESULTS_DIR/current_test.log"

INDEX=0
for test_file in "${ALL_TESTS[@]}"; do
  INDEX=$((INDEX + 1))
  
  if [[ "${ALREADY_PASSED[$test_file]:-0}" -eq 1 ]]; then
    echo "[$INDEX/$TOTAL_DISCOVERED] SKIP (already PASS): $test_file"
    continue
  fi

  echo -n "[$INDEX/$TOTAL_DISCOVERED] RUN: $test_file ... "

  # Run test with 900s timeout
  rm -f "$RUN_TMP_LOG"
  timeout 900 flutter test "$test_file" --reporter compact > "$RUN_TMP_LOG" 2>&1
  TEST_EXIT=$?

  # Extract the last summary line
  SUMMARY_LINE=$(tr '\r' '\n' < "$RUN_TMP_LOG" | grep -E '[0-9]{2}:[0-9]{2} \+[0-9]+' | tail -n 1)

  passed=0
  failed=0
  skipped=0

  if [[ -n "$SUMMARY_LINE" ]]; then
    if [[ "$SUMMARY_LINE" =~ \+([0-9]+) ]]; then
      passed="${BASH_REMATCH[1]}"
    fi
    if [[ "$SUMMARY_LINE" =~ -([0-9]+) ]]; then
      failed="${BASH_REMATCH[1]}"
    fi
    if [[ "$SUMMARY_LINE" =~ ~([0-9]+) ]]; then
      skipped="${BASH_REMATCH[1]}"
    fi
  fi

  if [[ $TEST_EXIT -eq 0 && $failed -eq 0 && $passed -gt 0 ]]; then
    status="PASS"
  else
    status="FAIL"
    # If exit was non-zero but failed count wasn't parsed, attribute at least 1 failure
    if [[ $failed -eq 0 && $passed -eq 0 ]]; then
      failed=1
    fi
  fi

  echo "$status (+$passed -$failed ~$skipped)"

  # Remove any prior entry for this test file from results file before appending new result
  if grep -q "^$test_file	" "$RESULTS_FILE" 2>/dev/null; then
    awk -F'\t' -v f="$test_file" '$1 != f' "$RESULTS_FILE" > "$RESULTS_FILE.tmp"
    mv "$RESULTS_FILE.tmp" "$RESULTS_FILE"
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" "$test_file" "$status" "$passed" "$failed" "$skipped" >> "$RESULTS_FILE"
done

rm -f "$RUN_TMP_LOG"

echo ""
echo "=================================================="
echo "FINAL RESULTS TABLE"
echo "=================================================="
printf "%-65s | %-6s | %-6s | %-6s | %-6s\n" "Test File" "Status" "Passed" "Failed" "Skip"
printf "%s\n" "------------------------------------------------------------------------------------------------------"

TOTAL_FILES=0
PASS_FILES=0
FAIL_FILES=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
ZERO_TEST_FILES=0

declare -A RECORDED_FILES

while IFS=$'\t' read -r r_file r_status r_p r_f r_s; do
  [[ -z "$r_file" ]] && continue
  TOTAL_FILES=$((TOTAL_FILES + 1))
  RECORDED_FILES["$r_file"]=1
  
  TOTAL_PASSED=$((TOTAL_PASSED + r_p))
  TOTAL_FAILED=$((TOTAL_FAILED + r_f))
  TOTAL_SKIPPED=$((TOTAL_SKIPPED + r_s))

  if [[ "$r_status" == "PASS" ]]; then
    PASS_FILES=$((PASS_FILES + 1))
  else
    FAIL_FILES=$((FAIL_FILES + 1))
  fi

  if [[ "$r_p" -eq 0 && "$r_f" -eq 0 ]]; then
    ZERO_TEST_FILES=$((ZERO_TEST_FILES + 1))
  fi

  printf "%-65s | %-6s | %-6s | %-6s | %-6s\n" "$r_file" "$r_status" "$r_p" "$r_f" "$r_s"
done < "$RESULTS_FILE"

printf "%s\n" "------------------------------------------------------------------------------------------------------"
echo "SUMMARY:"
echo "Files Discovered : $TOTAL_DISCOVERED"
echo "Files Executed   : $TOTAL_FILES"
echo "Files Passed     : $PASS_FILES"
echo "Files Failed     : $FAIL_FILES"
echo "Tests Passed     : $TOTAL_PASSED"
echo "Tests Failed     : $TOTAL_FAILED"
echo "Tests Skipped    : $TOTAL_SKIPPED"
echo "Total Executed   : $((TOTAL_PASSED + TOTAL_FAILED))"
echo "=================================================="

# Validation checks:
EXIT_CODE=0

# Check 1: Any file failed
if [[ $FAIL_FILES -gt 0 || $TOTAL_FAILED -gt 0 ]]; then
  echo "VALIDATION ERROR: $FAIL_FILES test file(s) failed." >&2
  EXIT_CODE=1
fi

# Check 2: Any file reported 0 tests
if [[ $ZERO_TEST_FILES -gt 0 ]]; then
  echo "VALIDATION ERROR: $ZERO_TEST_FILES file(s) reported 0 executed tests." >&2
  EXIT_CODE=1
fi

# Check 3: Any discovered file not run
for tf in "${ALL_TESTS[@]}"; do
  if [[ "${RECORDED_FILES[$tf]:-0}" -ne 1 ]]; then
    echo "VALIDATION ERROR: Discovered test file not recorded in results: $tf" >&2
    EXIT_CODE=1
  fi
done

exit $EXIT_CODE
