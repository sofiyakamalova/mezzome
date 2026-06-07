import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';

class DishStatusColors {
  static Color forStatus(DishStatus status) => switch (status) {
    DishStatus.ok => AppColors.textSecondary,
    DishStatus.deviation => AppColors.warningAmber,
    DishStatus.overrun => AppColors.dangerRed,
    DishStatus.draft => AppColors.border,
  };

  static String label(DishStatus status) => switch (status) {
    DishStatus.ok => 'dishStatusOk'.tr(),
    DishStatus.deviation => 'dishStatusDeviation'.tr(),
    DishStatus.overrun => 'dishStatusOverrun'.tr(),
    DishStatus.draft => 'dishStatusDraft'.tr(),
  };
}

String formatMoney(double? value) {
  if (value == null) {
    return 'notAvailable'.tr();
  }
  return '${value.toStringAsFixed(0)} ₸';
}

String formatPercent(double? value) {
  if (value == null) {
    return 'notAvailable'.tr();
  }
  return '${value.toStringAsFixed(1)}%';
}

class DishListTile extends StatelessWidget {
  const DishListTile({
    super.key,
    required this.dish,
    required this.showFinancials,
    required this.onTap,
  });

  final DishModel dish;
  final bool showFinancials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = DishStatusColors.forStatus(dish.status);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        onTap: onTap,
        title: Text(dish.name),
        subtitle: showFinancials
            ? Text(
                'costPerPortion'.tr(
                  namedArgs: {
                    'cost': formatMoney(dish.costPerPortion),
                    'foodCost': formatPercent(dish.foodCostPct),
                  },
                ),
              )
            : Text(
                'portionWeight'.tr(
                  namedArgs: {
                    'weight':
                        dish.weight?.toStringAsFixed(0) ?? 'notAvailable'.tr(),
                  },
                ),
              ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            DishStatusColors.label(dish.status),
            style: TextStyle(color: statusColor, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
