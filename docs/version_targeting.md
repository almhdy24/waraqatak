# Version Targeting Semantics

**Specification Version:** 1.0  
**Scope:** Client (Flutter/Dart) and Server (CI4/PHP)

## 1. Syntax & Grammar
App versions follow the SemVer pattern with optional pre-release and build metadata:
```
MAJOR.MINOR.PATCH[-pre][+BUILD]
```
Where:
- `MAJOR`, `MINOR`, `PATCH` are non-negative integers.
- `pre` is an alphanumeric pre-release identifier (e.g. `alpha`, `beta.1`). Pre-release identifiers are ignored during version bound comparisons.
- `BUILD` is a non-negative integer (e.g. `+13`, `+16`).
- The client may report its version either as a single combined string (e.g. `"1.1.5-alpha+16"`) or as a base version string `"1.1.5-alpha"` accompanied by an explicit numeric `app_build` (e.g. `16`). If both are present, `app_build` takes precedence.

## 2. Parsing Algorithm
1. Strip leading and trailing whitespace.
2. If `app_build` integer is explicitly provided and > 0, bind it as the parsed build number.
3. Split the version string by `+`:
   - Left side: version core and pre-release.
   - Right side (if present and build not yet bound): parse numeric build number.
4. Split the left side by `-`:
   - Left side: numeric core `MAJOR.MINOR.PATCH`.
   - Right side: pre-release tag (discarded for comparison purposes).
5. Split numeric core by `.`:
   - Must contain at least `MAJOR`. If `MINOR` is missing, default to 0. If `PATCH` is missing, default to 0.

## 3. Comparison Rules
Given an evaluated version `A` and a bound `B`:
1. Compare numeric cores `(major, minor, patch)` in order:
   - If `A.major != B.major`, result is `A.major <=> B.major`.
   - If `A.minor != B.minor`, result is `A.minor <=> B.minor`.
   - If `A.patch != B.patch`, result is `A.patch <=> B.patch`.
2. If numeric cores are **equal**:
   - If bound `B` explicitly specifies a build number `B.build != null`:
     - If `A.build != null`, compare `A.build <=> B.build`.
     - If `A.build == null`, `A` is considered lower than `B` if `B.build > 0`.
   - If bound `B` does **not** specify a build number (`B.build == null`):
     - The build number is ignored; versions are considered **equal**.

## 4. Range Boundaries
- Bounds are inclusive (`min_app_version <= app_version <= max_app_version`).
- `min_app_version == null`: Unbounded lower bound (all versions up to max match).
- `max_app_version == null`: Unbounded upper bound (all versions from min match).
- Both null: Matches all versions.
- If `min_app_version > max_app_version`: Invalid configuration; the admin API rejects creation/update with HTTP 422.
- Missing or malformed client app version: Matches only unbounded notifications (`min == null && max == null`).
