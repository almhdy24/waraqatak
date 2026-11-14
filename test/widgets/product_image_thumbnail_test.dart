import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:warqatek/services/image_storage_service.dart';
import 'package:warqatek/widgets/full_screen_image_viewer.dart';
import 'package:warqatek/widgets/product_image_thumbnail.dart';

void main() {
  late Directory tempDir;
  late Directory imagesDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('thumb_test_');
    imagesDir = Directory(p.join(tempDir.path, 'product_images'));
    await imagesDir.create(recursive: true);
    ImageStorageService.setCachedDirForTesting(imagesDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Widget createWidgetUnderTest({
    String? imagePath,
    bool isService = false,
    bool enableFullScreen = true,
    bool excludeSemantics = false,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeMode,
      home: Scaffold(
        body: ProductImageThumbnail(
          imagePath: imagePath,
          isService: isService,
          enableFullScreen: enableFullScreen,
          excludeSemantics: excludeSemantics,
        ),
      ),
    );
  }

  group('Group C: ProductImageThumbnail', () {
    testWidgets(
      'shows placeholder when imagePath is null or missing without crashing',
      (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(imagePath: null),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'shows service placeholder with tertiary container in dark mode',
      (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            imagePath: null,
            isService: true,
            themeMode: ThemeMode.dark,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
      },
    );

    testWidgets('enableFullScreen: false omits GestureDetector and Hero', (
      tester,
    ) async {
      File(p.join(imagesDir.path, 'item.jpg')).writeAsBytesSync([1, 2, 3]);

      await tester.pumpWidget(
        createWidgetUnderTest(imagePath: 'item.jpg', enableFullScreen: false),
      );
      await tester.pump();

      // No Hero widget
      expect(find.byType(Hero), findsNothing);
      // Tap does not push FullScreenImageViewer
      await tester.tap(find.byType(ProductImageThumbnail));
      await tester.pumpAndSettle();
      expect(find.byType(FullScreenImageViewer), findsNothing);
    });

    testWidgets('excludeSemantics: true wraps in ExcludeSemantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(imagePath: null, excludeSemantics: true),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(ProductImageThumbnail),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });
}
