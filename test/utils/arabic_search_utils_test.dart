import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/utils/arabic_search_utils.dart';

void main() {
  group('ArabicSearchUtils Tests (Pure Unit Tests - Batch 8)', () {
    test('1. Alif variants are unified (أ, إ, آ, ٱ -> ا)', () {
      expect(ArabicSearchUtils.normalize('أحمد'), equals('احمد'));
      expect(ArabicSearchUtils.normalize('إبراهيم'), equals('ابراهيم'));
      expect(ArabicSearchUtils.normalize('آدم'), equals('ادم'));
      expect(ArabicSearchUtils.normalize('ٱلرحمن'), equals('الرحمن'));

      expect(ArabicSearchUtils.matches('أحمد علي', 'احمد'), isTrue);
      expect(ArabicSearchUtils.matches('ابراهيم حسن', 'إبراهيم'), isTrue);
      expect(ArabicSearchUtils.matches('آدم طه', 'ادم'), isTrue);
    });

    test('2. Taa Marbuta (ة) and Haa (ه) are unified', () {
      expect(ArabicSearchUtils.normalize('مؤسسة'), equals('مؤسسه'));
      expect(ArabicSearchUtils.normalize('شركة'), equals('شركه'));

      expect(ArabicSearchUtils.matches('مؤسسة التقنية', 'مؤسسه'), isTrue);
      expect(ArabicSearchUtils.matches('شركة النور', 'شركه'), isTrue);
      expect(ArabicSearchUtils.matches('مؤسسه الفرات', 'مؤسسة'), isTrue);
    });

    test('3. Yaa (ي) and Alif Maqsura (ى) are unified', () {
      expect(ArabicSearchUtils.normalize('على'), equals('علي'));
      expect(ArabicSearchUtils.normalize('مصطفى'), equals('مصطفي'));

      expect(ArabicSearchUtils.matches('علي بن أبي طالب', 'على'), isTrue);
      expect(ArabicSearchUtils.matches('مستشفى الأمل', 'مستشفي'), isTrue);
      expect(ArabicSearchUtils.matches('مصطفي كامل', 'مصطفى'), isTrue);
    });

    test('4. Tashkeel / Harakat and Tatweel are removed', () {
      expect(ArabicSearchUtils.normalize('أَحْمَدُ'), equals('احمد'));
      expect(ArabicSearchUtils.normalize('سُكَّرٌ'), equals('سكر'));
      expect(ArabicSearchUtils.normalize('مُؤَسَّسَةٌ'), equals('مؤسسه'));
      expect(ArabicSearchUtils.normalize('شــــركة'), equals('شركه'));

      expect(ArabicSearchUtils.matches('سكر أبيض', 'سُكَّر'), isTrue);
      expect(ArabicSearchUtils.matches('شــــركة المستقبل', 'شركة'), isTrue);
    });

    test('5. English / Latin letters are lowercased', () {
      expect(
        ArabicSearchUtils.normalize('iPhone 15 Pro'),
        equals('iphone 15 pro'),
      );
      expect(
        ArabicSearchUtils.matches('iPhone 15 Pro Max', 'iphone 15'),
        isTrue,
      );
    });

    test('6. Non-matching queries return false', () {
      expect(ArabicSearchUtils.matches('محمد أحمد', 'خالد'), isFalse);
      expect(ArabicSearchUtils.matches('عصير برتقال', 'تفاح'), isFalse);
    });

    test('7. Empty and null queries handled gracefully', () {
      expect(ArabicSearchUtils.matches('محمد', ''), isTrue);
      expect(ArabicSearchUtils.matches('', 'محمد'), isFalse);
      expect(ArabicSearchUtils.matches(null, 'محمد'), isFalse);
      expect(ArabicSearchUtils.matches('محمد', null), isFalse);
    });

    test('8. sqlNormalize produces valid SQLite REPLACE expression', () {
      final expr = ArabicSearchUtils.sqlNormalize('name');
      expect(expr, contains("REPLACE("));
      expect(expr, contains("'أ', 'ا'"));
      expect(expr, contains("'إ', 'ا'"));
      expect(expr, contains("'آ', 'ا'"));
      expect(expr, contains("'ة', 'ه'"));
      expect(expr, contains("'ى', 'ي'"));
    });
  });
}
