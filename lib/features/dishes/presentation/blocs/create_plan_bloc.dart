import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';
import 'package:mezzome/features/dishes/domain/use_cases/create_production_plan_use_case.dart';
import 'package:mezzome/features/dishes/domain/use_cases/load_plan_form_use_case.dart';

part 'create_plan_event.dart';
part 'create_plan_state.dart';

/// BLoC составления плана. Зависит только от domain (use_cases). Роль передаётся
/// при создании (из authSessionProvider на экране) — нужна для ветвления API.
class CreatePlanBloc extends Bloc<CreatePlanEvent, CreatePlanState> {
  CreatePlanBloc({
    required UserRole? role,
    required LoadPlanFormUseCase loadForm,
    required CreateProductionPlanUseCase createPlan,
  })  : _role = role,
        _loadForm = loadForm,
        _createPlan = createPlan,
        super(CreatePlanState(date: DateFormatUtil.today, items: const [])) {
    on<CreatePlanStarted>((e, emit) => _bootstrap(emit));
    on<CreatePlanRetryBootstrap>((e, emit) => _bootstrap(emit));
    on<PlanServiceChanged>((e, emit) => emit(state.copyWith(service: e.service)));
    on<PlanDateChanged>((e, emit) => emit(state.copyWith(date: e.date)));
    on<PlanKitchenChanged>(
        (e, emit) => emit(state.copyWith(kitchenId: e.kitchenId)));
    on<PlanPeopleChanged>((e, emit) => emit(e.value == null
        ? state.copyWith(clearPeopleCount: true)
        : state.copyWith(peopleCount: e.value)));
    on<PlanReserveChanged>((e, emit) => emit(e.value == null
        ? state.copyWith(clearReserve: true)
        : state.copyWith(reserveCoefficient: e.value)));
    on<PlanNotesChanged>(
        (e, emit) => emit(state.copyWith(notes: (e.value ?? '').trim())));
    on<PlanItemAdded>((e, emit) => emit(state.copyWith(
          items: [...state.items, PlanDraftItem(key: _nextKey++)],
        )));
    on<PlanItemRemoved>((e, emit) {
      final next = state.items.where((i) => i.key != e.key).toList();
      emit(state.copyWith(
        items: next.isEmpty ? [PlanDraftItem(key: _nextKey++)] : next,
      ));
    });
    on<PlanItemDishChanged>((e, emit) => emit(state.copyWith(
          items: [
            for (final i in state.items)
              if (i.key == e.key)
                PlanDraftItem(
                    key: i.key, menuItemId: e.menuItemId, portions: i.portions)
              else
                i,
          ],
        )));
    on<PlanItemPortionsChanged>((e, emit) => emit(state.copyWith(
          items: [
            for (final i in state.items)
              if (i.key == e.key)
                PlanDraftItem(
                    key: i.key, menuItemId: i.menuItemId, portions: e.portions)
              else
                i,
          ],
        )));
    on<PlanFormReset>((e, emit) => emit(state.copyWith(
          items: [PlanDraftItem(key: _nextKey++)],
          clearPeopleCount: true,
          clearReserve: true,
          notes: '',
          clearSubmitError: true,
          fieldErrors: const {},
          clearCreatedPlan: true,
        )));
    on<PlanSubmitted>(_onSubmit);

    add(const CreatePlanStarted());
  }

  final UserRole? _role;
  final LoadPlanFormUseCase _loadForm;
  final CreateProductionPlanUseCase _createPlan;

  int _nextKey = 0;

  Future<void> _bootstrap(Emitter<CreatePlanState> emit) async {
    emit(state.copyWith(
      isBootstrapping: true,
      clearBootstrapError: true,
      items: state.items.isEmpty ? [PlanDraftItem(key: _nextKey++)] : state.items,
    ));
    try {
      final data = await _loadForm(_role);
      emit(state.copyWith(
        isBootstrapping: false,
        kitchens: data.kitchens,
        kitchenId: data.kitchens.isNotEmpty ? data.kitchens.first.id : null,
        catalog: data.catalog,
        categories: data.categories,
        clearBootstrapError: true,
      ));
    } on DioException catch (e) {
      appLogger.w('Create plan bootstrap failed: ${e.message}');
      emit(state.copyWith(
        isBootstrapping: false,
        bootstrapError: apiErrorDetails(e) ?? e.message ?? 'unknown',
      ));
    } catch (e) {
      appLogger.w('Create plan bootstrap failed: $e');
      emit(state.copyWith(isBootstrapping: false, bootstrapError: e.toString()));
    }
  }

  Future<void> _onSubmit(PlanSubmitted e, Emitter<CreatePlanState> emit) async {
    final kitchenId = state.kitchenId;
    final filled = state.filledItems;
    if (kitchenId == null || filled.isEmpty) return;

    final categoryById = {for (final c in state.categories) c.id: c};
    final dishById = {for (final d in state.catalog) d.id: d};

    final inputs = <ProductionPlanItemInput>[];
    for (var i = 0; i < filled.length; i++) {
      final item = filled[i];
      final dish = dishById[item.menuItemId];
      final category =
          dish?.categoryId != null ? categoryById[dish!.categoryId] : null;
      inputs.add(ProductionPlanItemInput(
        menuItemId: item.menuItemId!,
        plannedPortions: item.portions!,
        slotKey: category != null ? 'category_${category.id}' : null,
        slotTitle: category?.name,
        sortOrder: category?.sortOrder ?? (i + 1),
      ));
    }

    final request = ProductionPlanCreateRequest(
      kitchenId: kitchenId,
      serviceType: state.service.apiValue,
      plannedDate: DateFormatUtil.apiDate(state.date),
      peopleCount: state.peopleCount,
      reserveCoefficient: state.reserveCoefficient,
      notes: (state.notes ?? '').isEmpty ? null : state.notes,
      items: inputs,
    );

    emit(state.copyWith(
      isSubmitting: true,
      clearSubmitError: true,
      fieldErrors: const {},
    ));
    try {
      final plan = await _createPlan(_role, request);
      emit(state.copyWith(isSubmitting: false, createdPlan: plan));
    } on DioException catch (e) {
      appLogger.w('Create plan failed (HTTP ${e.response?.statusCode})');
      emit(state.copyWith(
        isSubmitting: false,
        submitError: apiErrorDetails(e) ?? e.message ?? 'unknown',
        fieldErrors: _parseValidation(e),
      ));
    } catch (e) {
      appLogger.w('Create plan failed: $e');
      emit(state.copyWith(isSubmitting: false, submitError: e.toString()));
    }
  }

  Map<String, String> _parseValidation(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['validation'] is Map) {
      final v = data['validation'] as Map;
      return {for (final entry in v.entries) '${entry.key}': '${entry.value}'};
    }
    return const {};
  }
}
