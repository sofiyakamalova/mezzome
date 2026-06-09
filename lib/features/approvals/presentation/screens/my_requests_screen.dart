import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_colors_light.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/data/repository/menu_dashboard_repository.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/presentation/providers/menu_dashboard_notifier.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/tech_card_editor_sheet.dart';

/// «Мои запросы на изменение» (роль chef): техкарты, отправленные на
/// согласование. Данные — `GET /chef/technical-cards?status=...`.
class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

enum _Filter {
  pending,
  rejected,
  approved;

  String get label => switch (this) {
        _Filter.pending => 'На согл.',
        _Filter.rejected => 'Отклон.',
        _Filter.approved => 'Утвержд.',
      };

  IconData get icon => switch (this) {
        _Filter.pending => Icons.hourglass_empty_rounded,
        _Filter.rejected => Icons.close_rounded,
        _Filter.approved => Icons.check_rounded,
      };
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  _Filter _filter = _Filter.pending;
  bool _loading = true;
  String? _error;
  List<TechnicalCardModel> _cards = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _statusValue => switch (_filter) {
        // Сервер хранит статус ожидающей версии как `pending_approval`.
        _Filter.pending => 'pending_approval',
        _Filter.rejected => 'rejected',
        _Filter.approved => 'approved',
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(technicalCardsApiProvider);
      final res = await api.listTechnicalCards(
        status: _statusValue,
        includeAllVersions: true,
      );
      appLogger.i(
        'My requests (status=$_statusValue): ${res.cards.length} cards',
      );
      if (!mounted) return;
      setState(() {
        _cards = res.cards;
        _loading = false;
      });
    } on DioException catch (e) {
      appLogger.w('My requests load failed: ${e.response?.statusCode}');
      if (!mounted) return;
      setState(() {
        _error = 'HTTP ${e.response?.statusCode}';
        _loading = false;
      });
    }
  }

  /// Тап по запросу → открыть техкарту по её id (просмотр/правка).
  Future<void> _openCard(TechnicalCardModel card) async {
    final notifier = ref.read(menuDashboardNotifierProvider.notifier);
    final session = ref.read(authSessionProvider).valueOrNull;
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

    await notifier.selectCell(cell, requestContext: true);
    if (!mounted) return;
    if (ref.read(menuDashboardNotifierProvider).editorDraft == null) {
      return;
    }
    await TechCardEditorSheet.show(
      context,
      signature: signature,
      showFinancials: showFinancials,
    );
    notifier.closeEditor();
    await _load();
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
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterTabs(
            selected: _filter,
            onSelected: (f) {
              if (f == _filter) return;
              setState(() => _filter = f);
              _load();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              color: ThemePalette.accent(context),
              onRefresh: _load,
              child: _buildList(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [Center(child: Text(_error!))],
      );
    }
    if (_cards.isEmpty) {
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
      itemCount: _cards.length,
      itemBuilder: (_, i) => _RequestCard(
        card: _cards[i],
        onTap: () => _openCard(_cards[i]),
      ),
    );
  }
}

/// Пилюли-табы фильтра запросов — в стиле приёмов пищи на дашборде
/// (`ServiceTabs`): трек-контейнер, активная вкладка с мягкой заливкой.
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onSelected});

  final _Filter selected;
  final ValueChanged<_Filter> onSelected;

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
            for (final filter in _Filter.values)
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

  final _Filter filter;
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
