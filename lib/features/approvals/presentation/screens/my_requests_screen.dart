import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_colors_light.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/approvals/domain/models/my_request_filter.dart';
import 'package:mezzome/features/approvals/presentation/blocs/my_requests_bloc.dart';
import 'package:mezzome/features/auth/presentation/blocs/auth_session_cubit.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/presentation/screens/tech_card_edit_page.dart';

/// «Мои запросы на изменение» (роль chef): техкарты, отправленные на
/// согласование. Данные — `GET /chef/technical-cards?status=...`.
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

/// UI-подписи/иконки для вкладок фильтра (модель — в domain).
extension _MyRequestFilterUi on MyRequestFilter {
  String get label => switch (this) {
        MyRequestFilter.pending => 'На согл.',
        MyRequestFilter.rejected => 'Отклон.',
        MyRequestFilter.approved => 'Утвержд.',
      };

  IconData get icon => switch (this) {
        MyRequestFilter.pending => Icons.hourglass_empty_rounded,
        MyRequestFilter.rejected => Icons.close_rounded,
        MyRequestFilter.approved => Icons.check_rounded,
      };
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  late final MyRequestsBloc _bloc =
      sl<MyRequestsBloc>()..add(const MyRequestsRequested());

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  /// Тап по запросу → полноэкранный редактор техкарты.
  Future<void> _openCard(TechnicalCardModel card) async {
    final session = sl<AuthSessionCubit>().state.user;
    final role = session?.role;
    final showFinancials = role != null && canSeeFinancials(role);
    final signature =
        session == null ? 'MEZZOME' : '${session.name} | MEZZOME';

    final cell = MenuGridCell(
      rowKey: 'req_${card.id}',
      rowLabel: card.categoryName ?? '',
      date: DateFormatUtil.today,
      technicalCardId: card.id,
      dishName: card.name,
      plannedPortions: card.basePortions <= 0 ? 1 : card.basePortions.round(),
      costPerPortion: card.foodCost > 0 ? card.foodCost : null,
    );

    await TechCardEditPage.open(
      context,
      cell: cell,
      signature: signature,
      showFinancials: showFinancials,
      requestContext: true,
    );
    if (!mounted) return;
    _bloc.add(const MyRequestsRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои запросы'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () => _bloc.add(const MyRequestsRefreshed()),
          ),
        ],
      ),
      body: BlocBuilder<MyRequestsBloc, MyRequestsState>(
        bloc: _bloc,
        builder: (context, state) {
          return Column(
            children: [
              _FilterTabs(
                selected: state.filter,
                onSelected: (f) => _bloc.add(MyRequestsFilterChanged(f)),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: ThemePalette.accent(context),
                  onRefresh: () async =>
                      _bloc.add(const MyRequestsRefreshed()),
                  child: _buildList(context, state),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, MyRequestsState state) {
    if (state.status == MyRequestsStatus.loading && state.cards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == MyRequestsStatus.failure && state.cards.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [Center(child: Text(state.error ?? 'Ошибка загрузки'))],
      );
    }
    if (state.cards.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Здесь пусто.\nОтправьте правку техкарты из меню — '
              'она появится со статусом «На согласовании».',
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemePalette.onSurfaceMuted(context)),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: state.cards.length,
      itemBuilder: (_, i) => _RequestCard(
        card: state.cards[i],
        onTap: () => _openCard(state.cards[i]),
      ),
    );
  }
}

/// Пилюли-табы фильтра запросов — в стиле приёмов пищи на дашборде
/// (`ServiceTabs`): трек-контейнер, активная вкладка с мягкой заливкой.
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onSelected});

  final MyRequestFilter selected;
  final ValueChanged<MyRequestFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final track = ThemePalette.isLight(context)
        ? AppColorsLight.surfaceSecondary
        : AppColors.surface;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: ThemePalette.border(context)),
        ),
        child: Row(
          children: [
            for (final filter in MyRequestFilter.values)
              Expanded(
                child: _FilterTab(
                  filter: filter,
                  isActive: filter == selected,
                  onTap: () => onSelected(filter),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.filter,
    required this.isActive,
    required this.onTap,
  });

  final MyRequestFilter filter;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = ThemePalette.isLight(context);
    final activeFill =
        isLight ? AppColorsLight.accentSoftStrong : ThemePalette.accent(context);
    final activeText =
        isLight ? AppColorsLight.onAccentSoftStrong : AppColors.onPrimary;
    final inactiveText = ThemePalette.onSurfaceMuted(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? activeFill : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filter.icon,
              size: 16,
              color: isActive ? activeText : inactiveText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                filter.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isActive ? activeText : inactiveText,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.card, required this.onTap});

  final TechnicalCardModel card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = (card.status ?? '').toLowerCase();
    final badge = switch (s) {
      'approved' => (color: AppColors.profitGreen, label: 'Утверждено'),
      'rejected' => (color: AppColors.dangerRed, label: 'Отклонено'),
      'pending' ||
      'pending_approval' =>
        (color: AppColors.warningAmber, label: 'На согласовании'),
      'draft' => (color: AppColors.statusDraft, label: 'Черновик'),
      _ => (color: ThemePalette.onSurfaceMuted(context), label: s),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: ThemePalette.border(context)),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (card.categoryName != null)
                      Text(
                        card.categoryName!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: ThemePalette.onSurfaceMuted(context),
                            ),
                      ),
                    if (card.foodCost > 0)
                      Text(
                        'Food cost: ${card.foodCost.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: ThemePalette.onSurfaceMuted(context),
                            ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  badge.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: badge.color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ThemePalette.onSurfaceMuted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
