import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dishes/data/repository/menu_dashboard_repository.dart';
import 'package:mezzome/features/dishes/domain/tech_card_history.dart';

/// История версий техкарты: кто, когда и что изменил.
class TechCardHistorySheet extends ConsumerStatefulWidget {
  const TechCardHistorySheet({
    super.key,
    required this.cardId,
    required this.cardName,
  });

  final int cardId;
  final String cardName;

  /// Открывает лист истории для техкарты [cardId].
  static Future<void> show(
    BuildContext context, {
    required int cardId,
    required String cardName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) =>
          TechCardHistorySheet(cardId: cardId, cardName: cardName),
    );
  }

  @override
  ConsumerState<TechCardHistorySheet> createState() =>
      _TechCardHistorySheetState();
}

class _TechCardHistorySheetState extends ConsumerState<TechCardHistorySheet> {
  late Future<TechCardHistoryResult> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(menuDashboardRepositoryProvider)
        .loadTechnicalCardHistory(widget.cardId);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Material(
          color: ThemePalette.surfacePanel(context),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusMd),
            ),
            side: BorderSide(color: ThemePalette.border(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'techCardHistoryTitle'.tr(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            widget.cardName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: ThemePalette.onSurfaceMuted(context),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: ThemePalette.border(context)),
              Expanded(
                child: FutureBuilder<TechCardHistoryResult>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final result = snapshot.data;
                    final entries = result?.entries ?? const [];
                    if (entries.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            (result?.forbidden ?? false)
                                ? 'techCardHistoryForbidden'.tr()
                                : 'techCardHistoryEmpty'.tr(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: ThemePalette.onSurfaceMuted(context),
                                ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          Divider(color: ThemePalette.border(context)),
                      itemBuilder: (context, index) =>
                          _HistoryTile(entry: entries[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final TechCardHistoryEntry entry;

  /// `v2` либо `v1 → v2`, если известна версия-источник.
  String? get _versionLabel {
    final to = entry.toVersion;
    if (to == null) return null;
    final from = entry.fromVersion;
    return from == null ? 'v$to' : 'v$from → v$to';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = ThemePalette.onSurfaceMuted(context);
    final versionLabel = _versionLabel;

    final metaParts = <String>[
      if (entry.authorLabel != null) entry.authorLabel!,
      if (entry.timestamp != null)
        DateFormatUtil.formatDateTimeShort(entry.timestamp!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (versionLabel != null || entry.changeLevel != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  [
                    ?versionLabel,
                    ?entry.changeLevel,
                  ].join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.warningAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (entry.requiresApproval) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                'techCardHistoryRequiresApproval'.tr(),
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
        if (metaParts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              metaParts.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        if (entry.action != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              'techCardHistoryAction'.tr(namedArgs: {'action': entry.action!}),
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: muted,
              ),
            ),
          ),
        if (entry.changes.isNotEmpty)
          ...entry.changes.map(
            (change) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                '${change.field}: ${change.oldValue} → ${change.newValue}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        if (entry.changedFields.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              'techCardHistoryFields'.tr(
                namedArgs: {'fields': entry.changedFields.join(', ')},
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}
