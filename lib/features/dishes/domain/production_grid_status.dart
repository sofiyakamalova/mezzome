import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';

/// Визуальный статус ячейки меню-борда (как в прототипе: точка-индикатор).
enum GridCellStatus {
  ok, // норма
  deviation, // отклонение / нет на складе / есть предупреждения
  overrun, // перерасход / отклонён / отменён
  draft; // черновик / план не утверждён

  String get labelKey => switch (this) {
        GridCellStatus.ok => 'gridStatusOk',
        GridCellStatus.deviation => 'gridStatusDeviation',
        GridCellStatus.overrun => 'gridStatusOverrun',
        GridCellStatus.draft => 'gridStatusDraft',
      };

  Color get color => switch (this) {
        GridCellStatus.ok => AppColors.profitGreen,
        GridCellStatus.deviation => AppColors.warningAmber,
        GridCellStatus.overrun => AppColors.dangerRed,
        GridCellStatus.draft => AppColors.statusDraft,
      };
}

/// Маппинг серверного `status` производственного плана → визуальный статус.
GridCellStatus gridCellStatusFor(ProductionPlanGridCellItem item) {
  if (item.stockAvailable == false) {
    return GridCellStatus.overrun;
  }
  if (item.warnings.isNotEmpty) {
    return GridCellStatus.deviation;
  }
  final status = item.status?.toLowerCase().trim() ?? '';
  return switch (status) {
    'approved' ||
    'conditional_approved' ||
    'completed' ||
    'active' ||
    'in_progress' =>
      GridCellStatus.ok,
    'rejected' || 'cancelled' || 'canceled' => GridCellStatus.overrun,
    'draft' || 'planned' || '' => GridCellStatus.draft,
    _ => GridCellStatus.deviation,
  };
}
