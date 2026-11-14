import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/services/image_storage_service.dart';
import 'package:warqatek/widgets/product_image_picker.dart';

class _FakeImagePicker extends ImagePicker {
  LostDataResponse lostDataToReturn = LostDataResponse.empty();
  XFile? imageToReturn;
  PlatformException? exceptionToThrow;

  @override
  Future<LostDataResponse> retrieveLostData() async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return lostDataToReturn;
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return imageToReturn;
  }
}

void main() {
  late Directory tempDir;
  late Directory imagesDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('picker_test_');
    imagesDir = Directory(p.join(tempDir.path, 'product_images'));
    await imagesDir.create(recursive: true);
    ImageStorageService.setCachedDirForTesting(imagesDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Widget createWidgetUnderTest({
    String? imagePath,
    ValueChanged<String?>? onChanged,
    bool readOnly = false,
    ImagePicker? picker,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ProductImagePicker(
          imagePath: imagePath,
          onChanged: onChanged ?? (_) {},
          readOnly: readOnly,
          picker: picker,
        ),
      ),
    );
  }

  group('Group B: ProductImagePicker', () {
    testWidgets('B7: Displays placeholder with theme and semantics', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      final l10n = AppLocalizations('ar');
      expect(find.text(l10n.addPhoto), findsOneWidget);
      expect(find.text(l10n.imageCroppedHint), findsOneWidget);
    });

    testWidgets('B4: Opens bottom sheet on tap and displays options', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      expect(find.text(l10n.takePicture), findsOneWidget);
      expect(find.text(l10n.chooseFromGallery), findsOneWidget);
    });

    testWidgets(
      'B2: Handles camera permission denied PlatformException gracefully',
      (tester) async {
        final fakePicker = _FakeImagePicker()
          ..exceptionToThrow = PlatformException(
            code: 'camera_access_denied',
            message: 'Permission denied',
          );

        await tester.pumpWidget(createWidgetUnderTest(picker: fakePicker));
        await tester.pump();

        // Open sheet
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations('ar');
        // Tap Camera
        await tester.tap(find.text(l10n.takePicture));
        await tester.pumpAndSettle();

        // Verify warning snackbar
        expect(find.text(l10n.cameraPermissionDenied), findsOneWidget);
      },
    );

    testWidgets(
      'B2: Handles photo permission denied PlatformException gracefully',
      (tester) async {
        final fakePicker = _FakeImagePicker()
          ..exceptionToThrow = PlatformException(
            code: 'photo_access_denied',
            message: 'Photo permission denied',
          );

        await tester.pumpWidget(createWidgetUnderTest(picker: fakePicker));
        await tester.pump();

        // Open sheet
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations('ar');
        // Tap Gallery
        await tester.tap(find.text(l10n.chooseFromGallery));
        await tester.pumpAndSettle();

        // Verify warning snackbar
        expect(find.text(l10n.photoPermissionDenied), findsOneWidget);
      },
    );

    testWidgets('D3: ReadOnly hides picker interaction', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(readOnly: true));
      await tester.pump();

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');
      // Bottom sheet should NOT open
      expect(find.text(l10n.takePicture), findsNothing);
    });
  });
}
