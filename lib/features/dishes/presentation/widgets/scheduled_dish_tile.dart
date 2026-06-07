import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/presentation/widgets/dish_list_tile.dart';

class ScheduledDishTile extends StatelessWidget {
  const ScheduledDishTile({
    super.key,
    required this.item,
    required this.showFinancials,
    required this.onTap,
  });

  final ScheduledMenuItem item;
  final bool showFinancials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        onTap: onTap,
        title: Text(item.name),
        subtitle: Text(
          '${_serviceLabel(item.serviceType)} · '
          '${'portionsCount'.tr(namedArgs: {'count': '${item.plannedPortions}'})}'
          '${showFinancials && item.theoreticalCost != null && item.theoreticalCost! > 0 ? ' · ${formatMoney(item.theoreticalCost)}' : ''}',
        ),
        trailing: _StatusBadge(status: item.planStatus),
      ),
    );
  }

  String _serviceLabel(String serviceType) => switch (serviceType) {
    'breakfast' => 'serviceBreakfast'.tr(),
    'lunch' => 'serviceLunch'.tr(),
    'dinner' => 'serviceDinner'.tr(),
    'snack' => 'serviceSnack'.tr(),
    'banquet' => 'serviceBanquet'.tr(),
    _ => serviceType,
  };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' || 'completed' => AppColors.profitGreen,
      'draft' => AppColors.border,
      'rejected' => AppColors.dangerRed,
      _ => AppColors.warningAmber,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
