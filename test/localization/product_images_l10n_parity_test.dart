import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';

void main() {
  group('Group F & G4: Product Images Localization Parity', () {
    late AppLocalizations l10nAr;
    late AppLocalizations l10nEn;

    setUp(() {
      l10nAr = AppLocalizations('ar');
      l10nEn = AppLocalizations('en');
    });

    test(
      'All 16 product image keys have non-empty, localized Arabic and English strings with matching placeholders',
      () {
        final entries = <String, (String Function(), String Function())>{
          'posShowProductImages': (
            () => l10nAr.posShowProductImages,
            () => l10nEn.posShowProductImages,
          ),
          'posHideProductImages': (
            () => l10nAr.posHideProductImages,
            () => l10nEn.posHideProductImages,
          ),
          'quickSaleImagesSettingTitle': (
            () => l10nAr.quickSaleImagesSettingTitle,
            () => l10nEn.quickSaleImagesSettingTitle,
          ),
          'quickSaleImagesSettingDesc': (
            () => l10nAr.quickSaleImagesSettingDesc,
            () => l10nEn.quickSaleImagesSettingDesc,
          ),
          'cameraPermissionDenied': (
            () => l10nAr.cameraPermissionDenied,
            () => l10nEn.cameraPermissionDenied,
          ),
          'photoPermissionDenied': (
            () => l10nAr.photoPermissionDenied,
            () => l10nEn.photoPermissionDenied,
          ),
          'openAppSettings': (
            () => l10nAr.openAppSettings,
            () => l10nEn.openAppSettings,
          ),
          'imagePhotoRecovered': (
            () => l10nAr.imagePhotoRecovered,
            () => l10nEn.imagePhotoRecovered,
          ),
          'imageCroppedHint': (
            () => l10nAr.imageCroppedHint,
            () => l10nEn.imageCroppedHint,
          ),
          'imageInvalid': (
            () => l10nAr.imageInvalid,
            () => l10nEn.imageInvalid,
          ),
          'imageTooLarge': (
            () => l10nAr.imageTooLarge,
            () => l10nEn.imageTooLarge,
          ),
          'imageDiskFull': (
            () => l10nAr.imageDiskFull,
            () => l10nEn.imageDiskFull,
          ),
          'imageSemanticLabel': (
            () => l10nAr.imageSemanticLabel,
            () => l10nEn.imageSemanticLabel,
          ),
          'imageChangeSemanticLabel': (
            () => l10nAr.imageChangeSemanticLabel,
            () => l10nEn.imageChangeSemanticLabel,
          ),
          'imageRestoreSkipped': (
            () => l10nAr.imageRestoreSkipped(3),
            () => l10nEn.imageRestoreSkipped(3),
          ),
          'errProductInUse': (
            () => l10nAr.errProductInUse,
            () => l10nEn.errProductInUse,
          ),
        };

        expect(entries.length, 16, reason: 'Must contain exactly 16 keys');

        final arabicRegex = RegExp(r'[\u0600-\u06FF]');
        final englishRegex = RegExp(r'[a-zA-Z]');

        for (final entry in entries.entries) {
          final key = entry.key;
          final ar = entry.value.$1();
          final en = entry.value.$2();

          expect(
            ar.trim().isNotEmpty,
            isTrue,
            reason: '$key Arabic value is empty',
          );
          expect(
            en.trim().isNotEmpty,
            isTrue,
            reason: '$key English value is empty',
          );

          expect(ar, isNot(equals(key)), reason: '$key Arabic equals key name');
          expect(en, isNot(equals(key)), reason: '$key English equals key name');

          expect(
            arabicRegex.hasMatch(ar),
            isTrue,
            reason: '$key Arabic does not contain Arabic script',
          );
          expect(
            englishRegex.hasMatch(en),
            isTrue,
            reason: '$key English does not contain Latin script',
          );

          if (key == 'imageRestoreSkipped') {
            expect(
              ar.contains('3'),
              isTrue,
              reason: '$key Arabic placeholder missing',
            );
            expect(
              en.contains('3'),
              isTrue,
              reason: '$key English placeholder missing',
            );
          }
        }
      },
    );
  });
}
