import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/data/repository/menu_dashboard_repository.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';
import 'package:mezzome/features/dishes/domain/scale_variance.dart';
import 'package:mezzome/features/dishes/domain/tech_card_history.dart';

part 'tech_card_state.dart';

/// Логика страницы детали техкарты: грузит карту + блюдо + историю + факт по весам.
/// Отделена от UI, чтобы разные верстки (compact/expanded) читали один стейт.
class TechCardCubit extends Cubit<TechCardState> {
  TechCardCubit(this._repo) : super(const TechCardState.loading());

  final MenuDashboardRepository _repo;

  Future<void> load(ProductionPlanGridCellItem item) async {
    emit(const TechCardState.loading());
    try {
      TechnicalCardModel? card;
      if (item.technicalCardId != null) {
        card = await _repo.loadTechnicalCardFull(item.technicalCardId!);
      }
      if (card == null && item.menuItemId != null) {
        card = await _repo.findTechnicalCardByMenuItem(item.menuItemId!);
      }
      card ??= await _repo.findTechnicalCardByName(item.menuItemName ?? '');

      if (card == null) {
        emit(const TechCardState.notFound());
        return;
      }

      // Блюдо меню НЕ грузим: фото берём из card.photo_urls, КБЖУ/аллергены —
      // из compliance_summary. Раньше тут тянулся весь каталог /menu/items (167
      // блюд) ради одного — лишний тяжёлый запрос.
      final cardId = card.id;
      final history = await _repo.loadTechnicalCardHistory(cardId);
      final scale = await _repo.loadScaleVariance(cardId);

      emit(TechCardState.ready(TechCardData(
        card: card,
        history: history,
        scale: scale,
      )));
    } catch (e) {
      appLogger.w('TechCard load failed: $e');
      emit(const TechCardState.notFound());
    }
  }
}
