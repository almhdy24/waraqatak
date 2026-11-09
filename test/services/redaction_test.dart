import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/csv_service.dart';
import 'package:warqatek/services/pdf/pdf_report_builder.dart';

void main() {
  final testUser = AppUser(
    id: 'user-sales-1',
    workspaceId: AccessDao.defaultWorkspaceId,
    username: 'salesperson',
    displayName: 'Sales Rep',
    roleId: 'role-template-salesperson',
    isOwner: false,
    isActive: true,
    setupComplete: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final business = Business(
    id: 1,
    name: 'Test Store',
    ownerName: 'Store Owner',
    phone: '0123456789',
    address: 'Khartoum',
    currencyCode: 'SDG',
    taxRate: 0.15,
  );

  tearDown(() {
    SessionManager.instance.setMultiUserEnabledForTesting(false);
  });

  group('Product.redacted', () {
    final product = Product(
      id: 1,
      name: 'Product A',
      salePrice: 100.0,
      purchasePrice: 60.0,
      wholesalePrice: 85.0,
      referenceSalePrice: 10.0,
      referencePurchasePrice: 6.0,
      referenceWholesalePrice: 8.5,
      priceCurrency: 'USD',
    );

    test('redactCost zeroes purchasePrice and clears referencePurchasePrice', () {
      final redacted = product.redacted(redactCost: true);
      expect(redacted.salePrice, 100.0);
      expect(redacted.purchasePrice, 0.0);
      expect(redacted.referencePurchasePrice, isNull);
      expect(redacted.wholesalePrice, 85.0);
      expect(redacted.referenceWholesalePrice, 8.5);
    });

    test('redactWholesale clears wholesalePrice and referenceWholesalePrice', () {
      final redacted = product.redacted(redactWholesale: true);
      expect(redacted.salePrice, 100.0);
      expect(redacted.purchasePrice, 60.0);
      expect(redacted.referencePurchasePrice, 6.0);
      expect(redacted.wholesalePrice, isNull);
      expect(redacted.referenceWholesalePrice, isNull);
    });

    test('redacting neither preserves all prices', () {
      final redacted = product.redacted();
      expect(redacted.salePrice, 100.0);
      expect(redacted.purchasePrice, 60.0);
      expect(redacted.wholesalePrice, 85.0);
      expect(redacted.referencePurchasePrice, 6.0);
      expect(redacted.referenceWholesalePrice, 8.5);
    });
  });

  group('CsvService permission guard', () {
    test('exportProducts throws PermissionDeniedException if lacking data.export_csv', () async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testUser, {
        PermissionRegistry.productsViewCost,
      });

      expect(
        () => CsvService.instance.exportProducts(templateOnly: false),
        throwsA(isA<PermissionDeniedException>().having(
          (e) => e.permissionKey,
          'permissionKey',
          PermissionRegistry.dataExportCsv,
        )),
      );
    });

    test('applyImport throws PermissionDeniedException if lacking data.import_csv', () async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testUser, {
        PermissionRegistry.salesCreate,
      });

      expect(
        () => CsvService.instance.applyImport(
          rows: [],
          strategy: CsvDuplicateStrategy.skip,
        ),
        throwsA(isA<PermissionDeniedException>().having(
          (e) => e.permissionKey,
          'permissionKey',
          PermissionRegistry.dataImportCsv,
        )),
      );
    });
  });

  group('PdfReportBuilder permissions', () {
    test('throws PermissionDeniedException when lacking reports.export_pdf', () async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testUser, {
        PermissionRegistry.salesCreate,
      });

      final data = PdfReportData(
        title: 'Sales Report',
        columns: [PdfReportColumn(title: 'Col 1', flex: 1)],
        rows: [
          ['Val 1'],
        ],
      );

      expect(
        () => PdfReportBuilder.build(
          business: business,
          l10n: AppLocalizations('en'),
          data: data,
        ),
        throwsA(isA<PermissionDeniedException>().having(
          (e) => e.permissionKey,
          'permissionKey',
          PermissionRegistry.reportsExportPdf,
        )),
      );
    });
  });
}
