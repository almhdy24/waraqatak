# Release Merge & Verification Log: v1.1.5-beta+16

## Step 1 — Preflight Audit

- **Date / Timestamp:** 2026-11-01T02:16:11Z
- **Active Repository:** `./waraqatak` (APP ONLY)
- **Default Branch:** `main` (confirmed via `remotes/origin/HEAD -> origin/main`)
- **Remote:** `origin` (`git@github.com:almhdy24/waraqatak.git`)
- **Working Tree State:** Clean (`git status --porcelain` produced zero output)

### Initial Commit SHAs (Rollback Points)
- **Local `main` SHA:** `fbbbf62ef42ee31586ca181869d84ef2956a2c80`
- **Remote `origin/main` SHA:** `fbbbf62ef42ee31586ca181869d84ef2956a2c80`
- **Status:** Local `main` is in exact lockstep with `origin/main` (0 commits ahead, 0 commits behind).

### Target Tag Check
- **Tag:** `v1.1.5-beta+16`
- **Local check (`git tag -l`):** Not found
- **Remote check (`git ls-remote origin refs/tags/v1.1.5-beta+16`):** Not found
- **Result:** Preflight check passed. Tag does not exist.

### Lineage Proof
Strict linear ancestry verified via `git merge-base --is-ancestor`:
1. `main` (`fbbbf62`) $\to$ `feat/finding-4-costing-migration-v20` (`a284073` / `v1.1.5-alpha+15`): **CONFIRMED**
2. `feat/finding-4-costing-migration-v20` $\to$ `ux/ui-polish` (`5d63f2a`): **CONFIRMED**
3. `ux/ui-polish` $\to$ `l10n/localization-polish` (`52de111`): **CONFIRMED**
4. `l10n/localization-polish` $\to$ `audit/units-wholesale` (`4b2b962`): **CONFIRMED**
5. `audit/units-wholesale` $\to$ `fix/units-wholesale` (`72be7e8`): **CONFIRMED**
6. `fix/units-wholesale` $\to$ `feat/license-hardening` (`6ec5f1d`): **CONFIRMED**

All branches form a continuous direct lineage ending at `feat/license-hardening`. No separate branch merges are required prior to merging `feat/license-hardening`.

---

## Step 2 — Working Tree Cleanup & Version Bump
- **Commit `4ca469d`:** `chore(release): 1.1.5-beta+16` on `feat/license-hardening`.
- **Files Bumped:**
  - `pubspec.yaml`: `version: 1.1.5-beta+16`
  - `lib/core/constants/app_constants.dart`: `appBuild = 16`, `appVersion = '1.1.5'`
  - `test/utils/version_matcher_test.dart`: Added test asserting `1.1.5-alpha+15 < 1.1.5-beta+16`
  - `docs/release-notes-1.1.5-beta+16.md`: Release notes created in standard format.

---

## Step 3 — Merge to Main
- **Command:** `git merge --no-ff feat/license-hardening -m "Merge feat/license-hardening: UX polish, l10n, units/wholesale fixes, licensing hardening (1.1.5-beta+16)"`
- **Strategy:** Clean recursive ort merge; zero conflicts.
- **Merge Commit SHA:** `496d2f104845e1f232879c4858822ae35a3c8bd2`
- **Tree Equivalence Proof:** `git diff feat/license-hardening main` produced zero output (empty diff).
- **Post-Merge Analysis:** `dart analyze lib/services lib/screens lib/database lib/localization` passed with zero errors (`No issues found!`).

---

## Step 4 — Push and Tag Verification
- **Push Main:** `git push origin main` $\to$ `fbbbf62..496d2f1 main -> main`
  - Local `main` SHA: `496d2f104845e1f232879c4858822ae35a3c8bd2`
  - Remote `origin/main` SHA: `496d2f104845e1f232879c4858822ae35a3c8bd2`
- **Annotated Tag:** `v1.1.5-beta+16` created (`git tag -a v1.1.5-beta+16 -m "Waraqatak v1.1.5-beta+16"`)
- **Push Tag:** `git push origin v1.1.5-beta+16` $\to$ `* [new tag] v1.1.5-beta+16 -> v1.1.5-beta+16`
  - Tag Object SHA: `e6c6df79d9c853df0d434790701cc5589ad82781`
  - Peeled Tag Target SHA (`refs/tags/v1.1.5-beta+16^{}`): `496d2f104845e1f232879c4858822ae35a3c8bd2` (exactly equals merge commit).

---

## Step 5 — GitHub Actions CI Status & Diagnostics
- **Workflow Run:** Release workflow run #41265851946
- **URL:** https://github.com/almhdy24/waraqatak/actions/runs/41265851946
- **Result:** Failed on CI full-suite test step (`870 tests passed, 1 failed, 21 skipped`).
- **Failing Test:**
  - `test/services/multi_currency_phase1_test.dart:542`
  - Test: `Finding 5 Phase 1 - CustomerDetailScreen Document Tile Currency Display 5. CustomerDetailScreen renders each document tile with its own currency symbol in production UI`
- **Root Cause Diagnosis:**
  - In `ux/ui-polish` (Batch 2), `lib/screens/customer_detail_screen.dart:771` was refactored to use the standardized accessible widget `AppAmountText`.
  - `AppAmountText` renders formatted numeric figures and currency symbols as separate sibling `Text` widgets inside a `Row` to preserve tabular figures and prevent RTL digit inversion.
  - The older test in `multi_currency_phase1_test.dart` used `find.textContaining('50,000 ج.س')`, which looks for a single combined `Text` widget with both amount and symbol concatenated.
- **Stop-and-Report Status:** Per safety instructions, no speculative fixes or re-runs with changes were pushed without reporting.

---

## Step 6 — Rollback & Remediation Instructions

### If Rollback of Merge is Desired:
To revert the merge commit cleanly on `main` without rewriting history:
```bash
git checkout main
git revert -m 1 496d2f104845e1f232879c4858822ae35a3c8bd2
git push origin main
```

### To Fix the Single Failing Test and Publish Pre-Release:
1. Update `test/services/multi_currency_phase1_test.dart:542-563` to match `AppAmountText` or search for amount and symbol within the card:
```dart
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('50,000.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('ج.س'),
        ),
        findsOneWidget,
      );
```
2. Commit on `main`.
3. Retag or push to trigger release build.

---

## Step 7 — Items Not Verified in this Termux Environment
1. **Real Physical Android Device Checks:**
   - Visual inspection of Arabic Nastaliq/Amiri PDF font rendering on thermal printers.
   - Physical camera barcode scanner tests.
   - Real-world activation against `api.almhdy24.com` (strictly prohibited in local headless testing).
2. **API & Admin Panel Repositories:**
   - Neither `../api.almhdy24.com` nor `../panel.almhdy24.com` had any branch switches, merges, or pushes performed. Database migrations remain in SQL scripts ready for phpMyAdmin manual application.


# Release Merge & Verification Log: v1.1.5-beta+17

## Step 1 — Preflight Audit

- **Date / Timestamp:** 2026-11-01T08:20:00Z
- **Active Repository:** `./waraqatak` (APP ONLY)
- **Default Branch:** `main` (confirmed via `remotes/origin/HEAD -> origin/main`)
- **Remote:** `origin` (`git@github.com:almhdy24/waraqatak.git`)
- **Working Tree State:** Clean (`git status --porcelain` produced zero output)

### Initial Commit SHAs (Rollback Points)
- **Local `main` SHA:** `d150613ef9ca596999b98be99e7bef8c903ab085`
- **Remote `origin/main` SHA:** `d150613ef9ca596999b98be99e7bef8c903ab085`
- **Status:** Local `main` is in exact lockstep with `origin/main` (0 commits ahead, 0 commits behind).

### Target Tag Check
- **Tag:** `v1.1.5-beta+17`
- **Local check (`git tag -l`):** Not found
- **Remote check (`git ls-remote origin refs/tags/v1.1.5-beta+17`):** Not found
- **Result:** Preflight check passed. Tag does not exist.

### Pending Feature / Fix Branches to Merge
1. **`feat/single-currency-accounting-audit`**
   - Tip SHA: `59232a3`
   - Commits ahead of main: 7 (`b2ed04b`, `4cfffbc`, `e9efcf4`, `994940f`, `23cdf36`, `52e916b`, `59232a3`)
   - Description: Single base currency transition, BUG-01 precision scaling fix, accounting invariant & oracle suites, 8 structural guards, full test runner.
2. **`fix/ui-cleanup-settings-support`**
   - Tip SHA: `a9e63dd`
   - Commits ahead of main: 3 (`f9fdd24`, `8bf2f92`, `a9e63dd`)
   - Description: Removed wholesale toggle from Financial Settings (preserved in Settings with confirmation dialog); removed support guidance card and about/copy buttons from UI surfaces.
3. **`fix/android-app-label-arabic`**
   - Tip SHA: `ab22fb3`
   - Commits ahead of main: 1 (`ab22fb3`)
   - Description: Ensured Android launcher label permanently resolves to Arabic "ورقتك" via `@string/app_name` across all locales.

### Overlap Proof
Comparing `git diff --name-only main..<branch>` across all three branches:
- `feat/single-currency-accounting-audit`: Touched accounting/currency screens, services, models, tests, docs, test runner.
- `fix/ui-cleanup-settings-support`: Touched `financial_settings_screen`, `settings_screen`, `activation_screen`, `license_screen`, `locked_feature_screen`, `pro_upgrade_sheet`, `docs/ui_cleanup_log.md`.
- `fix/android-app-label-arabic`: Touched `android/app/src/main/res/values/strings.xml` and deleted `android/app/src/main/res/values-ar/strings.xml`.
- **Intersection:** Exactly 0 overlapping files. Merge conflicts will be non-existent.


## Merge & Release Execution Report (1.1.5-beta+17)

### 1. Merge History & Commit SHAs
- **Merge 1 (Accounting Audit & Single Currency):** `736d1af` (`Merge branch 'feat/single-currency-accounting-audit' into release/1.1.5-beta+17`)
- **Merge 2 (UI Settings & Support Cleanup):** `0eef86f` (`Merge branch 'fix/ui-cleanup-settings-support' into release/1.1.5-beta+17`)
- **Merge 3 (Arabic Launcher Label):** `54273fe` (`Merge branch 'fix/android-app-label-arabic' into release/1.1.5-beta+17`)
- **Version Bump Commit:** `d082647` (`chore(release): 1.1.5-beta+17`)
- **Fast-forward Merge into `main`:** `d082647`
- **Release Tag:** `v1.1.5-beta+17` (Tag object SHA: `fbf4fb37e345e7f9e6fe082fa04d48d186ba9998`, Target commit SHA: `d082647cbd359574bd00127374dcecb85e8813da`)

### 2. Verification & CI Status
- **Play Compliance Guard:** PASS (`Play compliance guard: OK`)
- **Static Analysis:** PASS (`dart analyze lib/... test` - 0 errors, 1 preexisting info in elmahdi_pay_flutter)
- **GitHub Actions CI (Main Push Gate):** [Run 41291610756](https://github.com/almhdy24/waraqatak/actions/runs/41291610756)
  - `Analyze & Test`: PASS in 3m39s (100% tests passed)
  - `Build Release APKs`: PASS in 10m2s
- **GitHub Actions Release Workflow:** [Run 41291978233](https://github.com/almhdy24/waraqatak/actions/runs/41291978233)
  - `Build & Publish Release`: PASS in 17m28s
  - All artifacts built and signed:
    - `Waraqatak-v1.1.5-beta+17-arm64-v8a.apk` (30.11 MiB)
    - `Waraqatak-v1.1.5-beta+17.apk` (83.99 MiB)
    - `Waraqatak-v1.1.5-beta+17.aab` (57.79 MiB)
    - `mapping-v1.1.5-beta+17.txt` (25.31 MiB)

### 3. GitHub Release
- **Release URL:** https://github.com/almhdy24/waraqatak/releases/tag/v1.1.5-beta%2B17
- **Type:** Pre-release
- **Tag:** `v1.1.5-beta+17`

### 4. Git Command History
```bash
# Branch & Preflight
git checkout -b release/1.1.5-beta+17 main
# Merges
git merge --no-ff feat/single-currency-accounting-audit -m "Merge branch 'feat/single-currency-accounting-audit' into release/1.1.5-beta+17"
git merge --no-ff fix/ui-cleanup-settings-support -m "Merge branch 'fix/ui-cleanup-settings-support' into release/1.1.5-beta+17"
git merge --no-ff fix/android-app-label-arabic -m "Merge branch 'fix/android-app-label-arabic' into release/1.1.5-beta+17"
# Version Bump
# (updated pubspec.yaml, app_constants.dart, version_matcher_test.dart, release-notes-1.1.5-beta+17.md)
git commit -am "chore(release): 1.1.5-beta+17"
# Merge to main & Push
git checkout main
git merge --ff-only release/1.1.5-beta+17
git push origin main
git push origin release/1.1.5-beta+17
# Tag & Release
git tag -a v1.1.5-beta+17 -m "1.1.5-beta+17"
git push origin v1.1.5-beta+17
```

### 5. Rollback Instructions
In case an unforeseen issue is discovered requiring a rollback:
```bash
# 1. Rollback release tag on remote (if deleting the pre-release is required):
gh release delete v1.1.5-beta+17 --yes
git push origin :refs/tags/v1.1.5-beta+17

# 2. Revert the release commits on main:
git checkout main
git revert -m 1 54273fe # Revert Arabic launcher label merge if needed
git revert -m 1 0eef86f # Revert UI cleanup merge if needed
git revert -m 1 736d1af # Revert accounting audit merge if needed
git push origin main
```
