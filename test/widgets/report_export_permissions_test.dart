import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/widgets/report_export_menu.dart';

void main() {
  group('ReportExportPermissions Pure Resolution Tests', () {
    test('resolves all actions when user has both PDF and CSV permissions', () {
      final actions = ReportExportPermissions.resolveVisibleActions(
        hasPdfPermission: true,
        hasCsvPermission: true,
        hasPrintPdf: true,
        hasSharePdf: true,
        hasShareWhatsApp: true,
        hasExportCsv: true,
      );

      expect(actions.contains(ReportExportAction.printPdf), isTrue);
      expect(actions.contains(ReportExportAction.sharePdf), isTrue);
      expect(actions.contains(ReportExportAction.shareWhatsApp), isTrue);
      expect(actions.contains(ReportExportAction.exportCsv), isTrue);
      expect(actions.length, equals(4));
    });

    test('hides CSV action when user lacks CSV permission', () {
      final actions = ReportExportPermissions.resolveVisibleActions(
        hasPdfPermission: true,
        hasCsvPermission: false,
        hasPrintPdf: true,
        hasSharePdf: true,
        hasShareWhatsApp: true,
        hasExportCsv: true,
      );

      expect(actions.contains(ReportExportAction.printPdf), isTrue);
      expect(actions.contains(ReportExportAction.sharePdf), isTrue);
      expect(actions.contains(ReportExportAction.shareWhatsApp), isTrue);
      expect(actions.contains(ReportExportAction.exportCsv), isFalse);
      expect(actions.length, equals(3));
    });

    test('hides PDF and WhatsApp actions when user lacks PDF permission', () {
      final actions = ReportExportPermissions.resolveVisibleActions(
        hasPdfPermission: false,
        hasCsvPermission: true,
        hasPrintPdf: true,
        hasSharePdf: true,
        hasShareWhatsApp: true,
        hasExportCsv: true,
      );

      expect(actions.contains(ReportExportAction.printPdf), isFalse);
      expect(actions.contains(ReportExportAction.sharePdf), isFalse);
      expect(actions.contains(ReportExportAction.shareWhatsApp), isFalse);
      expect(actions.contains(ReportExportAction.exportCsv), isTrue);
      expect(actions.length, equals(1));
    });

    test('returns empty set when user lacks both permissions', () {
      final actions = ReportExportPermissions.resolveVisibleActions(
        hasPdfPermission: false,
        hasCsvPermission: false,
        hasPrintPdf: true,
        hasSharePdf: true,
        hasShareWhatsApp: true,
        hasExportCsv: true,
      );

      expect(actions.isEmpty, isTrue);
    });

    test('omits optional actions when their callbacks are not provided', () {
      final actions = ReportExportPermissions.resolveVisibleActions(
        hasPdfPermission: true,
        hasCsvPermission: true,
        hasPrintPdf: true,
        hasSharePdf: false,
        hasShareWhatsApp: false,
        hasExportCsv: false,
      );

      expect(actions.contains(ReportExportAction.printPdf), isTrue);
      expect(actions.contains(ReportExportAction.sharePdf), isFalse);
      expect(actions.contains(ReportExportAction.shareWhatsApp), isFalse);
      expect(actions.contains(ReportExportAction.exportCsv), isFalse);
      expect(actions.length, equals(1));
    });
  });

  group('ReportExportMenu.canExport Integration Tests', () {
    tearDown(() {
      SessionManager.instance.resetForTesting();
    });

    test('allows export in single-user mode', () {
      SessionManager.instance.setMultiUserEnabledForTesting(false);
      expect(ReportExportMenu.canExport(), isTrue);
    });

    test('evaluates permissions correctly in multi-user mode', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);

      final userWithoutExport = AppUser(
        id: 'usr-viewer',
        workspaceId: 'ws-default',
        roleId: 'role-viewer',
        username: 'viewer',
        displayName: 'Viewer',
        isOwner: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      SessionManager.instance.setSessionForTesting(
        userWithoutExport,
        permissions: {PermissionRegistry.reportsViewSales},
      );

      // User lacks reportsExportPdf and dataExportCsv
      expect(ReportExportMenu.canExport(), isFalse);

      // Grant CSV export only
      SessionManager.instance.setSessionForTesting(
        userWithoutExport,
        permissions: {
          PermissionRegistry.reportsViewSales,
          PermissionRegistry.dataExportCsv,
        },
      );
      expect(ReportExportMenu.canExport(hasPdf: false, hasCsv: true), isTrue);
      expect(ReportExportMenu.canExport(hasPdf: true, hasCsv: false), isFalse);
      expect(ReportExportMenu.canExport(hasPdf: true, hasCsv: true), isTrue);
    });
  });
}
