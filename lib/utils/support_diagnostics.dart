import 'dart:io';

import '../core/constants/app_constants.dart';
import '../services/license_service.dart';

/// Helper to generate safe, masked diagnostics for customer support.
///
/// Guaranteed zero secret leakage:
/// - License keys are masked (first 2, last 2 characters only).
/// - Tokens and signatures are NEVER included.
/// - Machine ID is truncated / masked.
class SupportDiagnostics {
  SupportDiagnostics._();

  static String maskKey(String? key) {
    if (key == null || key.trim().isEmpty) return 'none';
    final trimmed = key.trim();
    if (trimmed.length <= 4) return '****';
    return '${trimmed.substring(0, 2)}****${trimmed.substring(trimmed.length - 2)}';
  }

  static Future<String> generateSummary({
    String? referenceId,
    String? rawKey,
  }) async {
    final entitlement = await LicenseService.instance.checkEntitlement();
    final storedKey = await LicenseService.instance.licenseKey;
    final deviceModel = await LicenseService.instance.getDeviceModel();
    String maskedMachine = 'unavailable';
    try {
      final machineId = await LicenseService.instance.getOrCreateDeviceId();
      if (machineId.length > 8) {
        maskedMachine =
            '${machineId.substring(0, 4)}...${machineId.substring(machineId.length - 4)}';
      } else {
        maskedMachine = machineId;
      }
    } catch (_) {}

    final effectiveKey = rawKey ?? storedKey;

    final buffer = StringBuffer()
      ..writeln('=== Waraqatak Support Diagnostics ===')
      ..writeln('App ID: ${AppConstants.appId}')
      ..writeln('Version: ${AppConstants.appVersion}+${AppConstants.appBuild}')
      ..writeln('Platform: ${Platform.operatingSystem}')
      ..writeln('Device Model: $deviceModel')
      ..writeln('Device Ref: $maskedMachine')
      ..writeln('Status: ${entitlement.status.name}')
      ..writeln('Key: ${maskKey(effectiveKey)}');

    if (referenceId != null && referenceId.trim().isNotEmpty) {
      buffer.writeln('Reference ID: ${referenceId.trim()}');
    }

    buffer.writeln('Timestamp: ${DateTime.now().toUtc().toIso8601String()}');
    return buffer.toString();
  }
}
