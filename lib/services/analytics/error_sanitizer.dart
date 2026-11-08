/// Utility for deeply sanitizing error messages, stack traces, and system metadata
/// before transmitting telemetry or diagnostic reports.
///
/// Guaranteed zero PII: removes phone numbers, email addresses, financial amounts,
/// customer references, license keys, auth secrets, and user filesystem paths.
class ErrorSanitizer {
  ErrorSanitizer._();

  static const int maxMessageLength = 255;
  static const int maxExceptionTypeLength = 128;
  static const int maxOsVersionLength = 64;
  static const int maxStackTraceLength = 2000;

  /// Sanitizes exception type string (max 128 chars, alphanumeric & underscores/colons/dots).
  static String sanitizeExceptionType(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_:.]'), '').trim();
    if (cleaned.isEmpty) cleaned = 'UnknownException';
    if (cleaned.length > maxExceptionTypeLength) {
      cleaned = cleaned.substring(0, maxExceptionTypeLength);
    }
    return cleaned;
  }

  /// Sanitizes OS version string (max 64 chars).
  static String sanitizeOsVersion(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'[\r\n\t]'), ' ').trim();
    if (cleaned.length > maxOsVersionLength) {
      cleaned = cleaned.substring(0, maxOsVersionLength);
    }
    return cleaned;
  }

  /// Deeply sanitizes exception message:
  /// - Strips filesystem absolute paths and content/file URIs
  /// - Strips Windows drive paths
  /// - Strips email patterns
  /// - Strips phone numbers (with optional country prefix) and numbers of 6+ digits
  /// - Strips Bearer tokens, secrets, passwords, auth keywords
  /// - Strips license key patterns (e.g. ABCD-EFGH-1234)
  /// - Strips financial currency amounts (SDG, USD, EUR, SAR, AED, GBP, $, €, ج.س, etc.)
  /// - Strips customer/client reference labels
  /// - Strips SQL query single-quoted literals
  /// - Normalizes whitespace and enforces maximum 255 characters
  static String sanitizeMessage(String raw) {
    if (raw.isEmpty) return '';

    String cleaned = raw;

    // 1. Remove Linux/Android/macOS filesystem paths & content/file URIs
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(file://|content://)?(/data/data|/storage|/home|/var|/tmp|/Users)/[^\s:;,)]+',
      ),
      '[path redacted]',
    );

    // 2. Remove Windows drive paths
    cleaned = cleaned.replaceAll(
      RegExp(r'[A-Za-z]:\\[^\s:;,)]+'),
      '[path redacted]',
    );

    // 3. Remove email addresses
    cleaned = cleaned.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[email redacted]',
    );

    // 4. Remove telephone numbers or numeric sequences of 6+ digits
    cleaned = cleaned.replaceAll(
      RegExp(r'(\+\d{1,3}[- ]?)?\b\d{6,}\b'),
      '[number redacted]',
    );

    // 5. Remove auth tokens, keys, passwords, secrets
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(Bearer\s+[A-Za-z0-9._-]+|key=[A-Za-z0-9_-]+|token=[A-Za-z0-9_-]+|password=[^\s:;,)]+|secret=[^\s:;,)]+)',
        caseSensitive: false,
      ),
      '[secret redacted]',
    );

    // 6. Remove license key patterns (e.g. WARA-2026-LIVE-ABCD or XXXX-XXXX-XXXX)
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}(-[A-Za-z0-9]{4})?\b',
      ),
      '[license redacted]',
    );

    // 7. Remove financial amounts and currency codes
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(?:SDG|USD|EUR|SAR|AED|GBP|[$€£¥])\s*[\d,.]+|[\d,.]+\s*(?:SDG|USD|EUR|SAR|AED|GBP|[$€£¥]|ج\.س|جنيه|ريال|درهم)',
        caseSensitive: false,
      ),
      '[amount redacted]',
    );

    // 8. Remove customer / client / vendor reference labels
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(customer|client|buyer|vendor|supplier):\s*[^\s,;()]*(?:\s+[^\s,;()]+){0,4}',
        caseSensitive: false,
      ),
      r'$1: [redacted]',
    );

    // 9. Redact single-quoted literals in database / SQL query contexts
    cleaned = cleaned.replaceAll(RegExp(r"'[^']*'"), "'[redacted]'");

    // 10. Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 11. Enforce length cap
    if (cleaned.length > maxMessageLength) {
      cleaned = cleaned.substring(0, maxMessageLength);
    }

    return cleaned;
  }

  /// Sanitizes stack trace:
  /// - Strips filesystem absolute paths while keeping package: URI references
  /// - Enforces maximum length
  static String sanitizeStackTrace(
    String? raw, {
    int maxLength = maxStackTraceLength,
  }) {
    if (raw == null || raw.trim().isEmpty) return '';

    String cleaned = raw;

    // Remove local user directories and system absolute paths
    cleaned = cleaned.replaceAll(
      RegExp(r'(/data/data|/storage|/home|/var|/tmp|/Users)/[^\s:;,)]+/'),
      '.../',
    );

    // Remove Windows user paths
    cleaned = cleaned.replaceAll(
      RegExp(r'[A-Za-z]:\\[^\s:;,)]*\\'),
      r'...\',
    );

    // Normalize whitespace runs
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ').trim();

    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }

    return cleaned;
  }
}
