import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mezzome/core/di/session_holder.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/data/models/user_model.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/data/repository/menu_dashboard_repository.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/domain/tech_card_draft.dart';
import 'package:mezzome/features/dishes/presentation/blocs/menu_dashboard_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MenuDashboardRepository {}

class _FakeDraft extends Fake implements TechCardDraft {}

class _FakeCard extends Fake implements TechnicalCardModel {}

/// Валидная строка ингредиента (id + брутто/нетто, нетто ≤ брутто).
TechCardIngredientDraft _ing() =>
    TechCardIngredientDraft(ingredientId: 1, name: 'Beef', brutto: 10, netto: 9);

/// Готовый черновик для правки (id задан, изменений нет → менеджеру не нужна
/// причина правки).
TechCardDraft _editDraft() {
  final d = TechCardDraft(
    id: 994170,
    name: 'Плов',
    categoryId: 5,
    ingredients: [_ing()],
  );
  d.originalSnapshot = d.copyForSnapshot();
  return d;
}

TechnicalCardModel _loadedCard() => const TechnicalCardModel(
      id: 994170,
      name: 'Плов',
      ingredients: [
        TechnicalCardIngredientModel(id: 1, ingredientId: 1, brutto: 10, netto: 9),
      ],
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    registerFallbackValue(_FakeDraft());
    registerFallbackValue(_FakeCard());
  });

  late _MockRepo repo;
  late SessionHolder session;

  MenuDashboardCubit build(UserRole role) {
    session = SessionHolder()
      ..user = UserModel(id: 1, name: 'DEV Chef', phone: '+7', role: role);
    return MenuDashboardCubit(repo, session);
  }

  setUp(() {
    repo = _MockRepo();
    when(() => repo.createTechnicalCard(
          draft: any(named: 'draft'),
          submitForApproval: any(named: 'submitForApproval'),
        )).thenAnswer((_) async => null);
    when(() => repo.saveTechnicalCard(
          id: any(named: 'id'),
          draft: any(named: 'draft'),
          submitForApproval: any(named: 'submitForApproval'),
        )).thenAnswer((_) async => null);
    when(() => repo.submitTechnicalCard(any())).thenAnswer((_) async => null);
    when(() => repo.approveTechnicalCard(any())).thenAnswer((_) async => null);
    when(() => repo.loadTechnicalCardFull(any()))
        .thenAnswer((_) async => _loadedCard());
    when(() => repo.draftFromTechnicalCard(
          any(),
          serviceLabel: any(named: 'serviceLabel'),
          dayLabel: any(named: 'dayLabel'),
          categoryLabel: any(named: 'categoryLabel'),
          scheduleless: any(named: 'scheduleless'),
          plannedPortions: any(named: 'plannedPortions'),
          planItemId: any(named: 'planItemId'),
          menuItemId: any(named: 'menuItemId'),
        )).thenReturn(_editDraft());
  });

  // ── Создание ──────────────────────────────────────────────────────────
  test('создание + «На проверку» → createTechnicalCard(submit=true)', () async {
    final cubit = build(UserRole.chef);
    cubit.newDraft();
    cubit.state.editorDraft!
      ..name = 'Новое блюдо'
      ..categoryId = 5
      ..ingredients.add(_ing());

    final res = await cubit.saveAndSign(submit: true);

    expect(res.error, isNull);
    verify(() => repo.createTechnicalCard(
        draft: any(named: 'draft'), submitForApproval: true)).called(1);
    await cubit.close();
  });

  test('создание как черновик → createTechnicalCard(submit=false)', () async {
    final cubit = build(UserRole.chef);
    cubit.newDraft();
    cubit.state.editorDraft!
      ..name = 'Черновик'
      ..categoryId = 5
      ..ingredients.add(_ing());

    await cubit.saveAndSign(submit: false);

    verify(() => repo.createTechnicalCard(
        draft: any(named: 'draft'), submitForApproval: false)).called(1);
    await cubit.close();
  });

  test('создание без названия → ошибка, бэк не дёргается', () async {
    final cubit = build(UserRole.chef);
    cubit.newDraft();
    cubit.state.editorDraft!
      ..categoryId = 5
      ..ingredients.add(_ing());

    final res = await cubit.saveAndSign(submit: true);

    expect(res.error, isNotNull);
    verifyNever(() => repo.createTechnicalCard(
        draft: any(named: 'draft'), submitForApproval: any(named: 'submitForApproval')));
    await cubit.close();
  });

  test('создание без категории → ошибка (нужен category_id)', () async {
    final cubit = build(UserRole.chef);
    cubit.newDraft();
    cubit.state.editorDraft!
      ..name = 'Без категории'
      ..ingredients.add(_ing());

    final res = await cubit.saveAndSign(submit: true);

    expect(res.error, isNotNull);
    verifyNever(() => repo.createTechnicalCard(
        draft: any(named: 'draft'), submitForApproval: any(named: 'submitForApproval')));
    await cubit.close();
  });

  // ── Правка + отправка ─────────────────────────────────────────────────
  test('шеф: правка + «На проверку» → PATCH(submit=false) затем /submit',
      () async {
    final cubit = build(UserRole.chef);
    await cubit.selectCell(MenuGridCell(
      rowKey: 'r',
      rowLabel: 'Cat',
      date: _date,
      dishName: 'Плов',
      technicalCardId: 994170,
    ));

    await cubit.saveAndSign(submit: true);

    verify(() => repo.saveTechnicalCard(
        id: 994170,
        draft: any(named: 'draft'),
        submitForApproval: false)).called(1);
    verify(() => repo.submitTechnicalCard(994170)).called(1);
    verifyNever(() => repo.approveTechnicalCard(any()));
    await cubit.close();
  });

  test('шеф: правка как черновик → PATCH(submit=false) + best-effort approve',
      () async {
    final cubit = build(UserRole.chef);
    await cubit.selectCell(MenuGridCell(
      rowKey: 'r',
      rowLabel: 'Cat',
      date: _date,
      dishName: 'Плов',
      technicalCardId: 994170,
    ));

    await cubit.saveAndSign(submit: false);

    verify(() => repo.saveTechnicalCard(
        id: 994170,
        draft: any(named: 'draft'),
        submitForApproval: false)).called(1);
    verify(() => repo.approveTechnicalCard(994170)).called(1);
    verifyNever(() => repo.submitTechnicalCard(any()));
    await cubit.close();
  });

  test('менеджер: правка → PATCH(submit=true), без /submit', () async {
    final cubit = build(UserRole.manager);
    await cubit.selectCell(MenuGridCell(
      rowKey: 'r',
      rowLabel: 'Cat',
      date: _date,
      dishName: 'Плов',
      technicalCardId: 994170,
    ));

    await cubit.saveAndSign(submit: false);

    verify(() => repo.saveTechnicalCard(
        id: 994170,
        draft: any(named: 'draft'),
        submitForApproval: true)).called(1);
    verifyNever(() => repo.submitTechnicalCard(any()));
    await cubit.close();
  });
}

final _date = DateTime(2026, 6, 25);
