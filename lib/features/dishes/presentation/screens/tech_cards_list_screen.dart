import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/auth/presentation/blocs/auth_session_cubit.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';
import 'package:mezzome/features/dishes/presentation/blocs/tech_cards_list_cubit.dart';
import 'package:mezzome/features/dishes/presentation/screens/tech_card_edit_page.dart';
import 'package:mezzome/features/dishes/presentation/screens/tech_card_page.dart';

/// Вкладка «Техкарты» — все техкарты шефа. Тап → страница детали (с правкой).
class TechCardsListScreen extends StatefulWidget {
  const TechCardsListScreen({super.key});

  @override
  State<TechCardsListScreen> createState() => _TechCardsListScreenState();
}

class _TechCardsListScreenState extends State<TechCardsListScreen> {
  final TechCardsListCubit _cubit = sl<TechCardsListCubit>()..load();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  bool get _showMoney {
    final role = sl<AuthSessionCubit>().state.role;
    return role != null && canSeeFinancials(role);
  }

  String get _signature {
    final user = sl<AuthSessionCubit>().state.user;
    return user == null ? 'MEZZOME' : '${user.name} | MEZZOME';
  }

  Future<void> _create() async {
    await TechCardEditPage.openCreate(
      context,
      signature: _signature,
      showFinancials: _showMoney,
    );
    if (mounted) _cubit.load();
  }

  Future<void> _openCard(TechnicalCardModel card) async {
    final item = ProductionPlanGridCellItem(
      technicalCardId: card.id,
      technicalCardRootId: card.id,
      menuItemId: card.menuItemId,
      menuItemName: card.name,
      categoryName: card.categoryName,
    );
    final cell = MenuGridCell(
      rowKey: 'tc_${card.id}',
      rowLabel: card.categoryName ?? '',
      date: DateFormatUtil.today,
      technicalCardId: card.id,
      menuItemId: card.menuItemId,
      dishName: card.name,
    );
    await TechCardPage.open(
      context,
      item: item,
      date: null,
      signature: _signature,
      showFinancials: _showMoney,
      // Кнопка «Редактировать» на детали → полноэкранный редактор.
      onEdit: () => TechCardEditPage.open(
        context,
        cell: cell,
        signature: _signature,
        showFinancials: _showMoney,
        requestContext: true,
      ),
    );
    if (mounted) _cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('tcListTitle'.tr()),
        actions: [
          IconButton(
            tooltip: 'refreshTooltip'.tr(),
            icon: const Icon(Icons.refresh),
            onPressed: () => _cubit.load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text('tcCreate'.tr()),
      ),
      body: BlocBuilder<TechCardsListCubit, TechCardsListState>(
        bloc: _cubit,
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  onChanged: _cubit.setSearch,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'tcSearchHint'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _body(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, TechCardsListState state) {
    if (state.status == TechCardsListStatus.failure && state.cards.isEmpty) {
      return _centered(state.error ?? 'whUnavailable'.tr());
    }
    if (state.status == TechCardsListStatus.loading && state.cards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final cards = state.visible;
    if (cards.isEmpty) {
      return _centered('tcEmpty'.tr());
    }
    return RefreshIndicator(
      color: ThemePalette.accent(context),
      onRefresh: () async => _cubit.load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _TechCardTile(
          card: cards[i],
          showMoney: _showMoney,
          onTap: () => _openCard(cards[i]),
        ),
      ),
    );
  }

  Widget _centered(String message) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: ThemePalette.onSurfaceMuted(context)),
              ),
            ),
          ),
        ],
      );
}

class _TechCardTile extends StatelessWidget {
  const _TechCardTile({
    required this.card,
    required this.showMoney,
    required this.onTap,
  });

  final TechnicalCardModel card;
  final bool showMoney;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = (card.approvalStatus ?? card.status ?? '').toLowerCase();
    final badge = switch (s) {
      'approved' => (c: AppColors.profitGreen, t: 'Активна'),
      'rejected' => (c: AppColors.dangerRed, t: 'Отклонена'),
      'pending' || 'pending_approval' =>
        (c: AppColors.warningAmber, t: 'На согласовании'),
      'draft' => (c: ThemePalette.onSurfaceMuted(context), t: 'Черновик'),
      _ => (c: ThemePalette.onSurfaceMuted(context), t: card.status ?? ''),
    };

    return Container(
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (card.categoryName != null) card.categoryName!,
                        if (showMoney && card.foodCost > 0)
                          'food cost ${card.foodCost.toStringAsFixed(1)}%',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: ThemePalette.onSurfaceMuted(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.c.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  badge.t,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: badge.c, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: ThemePalette.onSurfaceMuted(context)),
            ],
          ),
        ),
      ),
    );
  }
}
