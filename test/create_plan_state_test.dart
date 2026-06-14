import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/dishes/presentation/providers/create_plan_state.dart';

void main() {
  final base = CreatePlanState(date: DateTime(2026, 6, 14));

  group('CreatePlanState.canSubmit', () {
    test('false without a kitchen', () {
      final s = base.copyWith(
        items: [const PlanDraftItem(key: 0, menuItemId: 1, portions: 10)],
      );
      expect(s.kitchenId, isNull);
      expect(s.canSubmit, isFalse);
    });

    test('false without any filled item', () {
      final s = base.copyWith(
        kitchenId: 1,
        items: [const PlanDraftItem(key: 0)],
      );
      expect(s.filledItems, isEmpty);
      expect(s.canSubmit, isFalse);
    });

    test('false while submitting', () {
      final s = base.copyWith(
        kitchenId: 1,
        items: [const PlanDraftItem(key: 0, menuItemId: 1, portions: 10)],
        isSubmitting: true,
      );
      expect(s.canSubmit, isFalse);
    });

    test('true with kitchen and a filled item', () {
      final s = base.copyWith(
        kitchenId: 1,
        items: [
          const PlanDraftItem(key: 0, menuItemId: 1, portions: 10),
          const PlanDraftItem(key: 1), // пустая строка игнорируется
        ],
      );
      expect(s.filledItems, hasLength(1));
      expect(s.canSubmit, isTrue);
    });
  });

  group('PlanDraftItem.isFilled', () {
    test('requires both dish and positive portions', () {
      expect(const PlanDraftItem(key: 0).isFilled, isFalse);
      expect(const PlanDraftItem(key: 0, menuItemId: 1).isFilled, isFalse);
      expect(
        const PlanDraftItem(key: 0, menuItemId: 1, portions: 0).isFilled,
        isFalse,
      );
      expect(
        const PlanDraftItem(key: 0, menuItemId: 1, portions: 5).isFilled,
        isTrue,
      );
    });
  });
}
