import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/utils/quick_sale_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('QuickSaleSettings', () {
    test('defaults showProductImages to true', () {
      final settings = QuickSaleSettings.instance;
      settings.setShowProductImagesForTesting(true);
      expect(settings.showProductImages, isTrue);
    });

    test('setShowProductImages updates value and notifies listeners', () async {
      final settings = QuickSaleSettings.instance;
      int notifications = 0;
      void listener() => notifications++;
      settings.addListener(listener);

      await settings.setShowProductImages(false);
      expect(settings.showProductImages, isFalse);
      expect(notifications, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(QuickSaleSettings.prefKey), isFalse);

      settings.removeListener(listener);
    });

    test('load retrieves value from SharedPreferences without throwing', () async {
      SharedPreferences.setMockInitialValues({
        QuickSaleSettings.prefKey: false,
      });

      final settings = QuickSaleSettings.instance;
      await settings.load();
      expect(settings.showProductImages, isFalse);

      SharedPreferences.setMockInitialValues({
        QuickSaleSettings.prefKey: true,
      });
      await settings.load();
      expect(settings.showProductImages, isTrue);
    });

    test('setShowProductImagesForTesting seeds value directly', () {
      final settings = QuickSaleSettings.instance;
      bool notified = false;
      void listener() => notified = true;
      settings.addListener(listener);

      settings.setShowProductImagesForTesting(false);
      expect(settings.showProductImages, isFalse);
      expect(notified, isTrue);

      settings.setShowProductImagesForTesting(true);
      expect(settings.showProductImages, isTrue);

      settings.removeListener(listener);
    });
  });
}
