import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/features/dishes/domain/journal_entry.dart';

class MenuJournalSheet extends StatelessWidget {
  const MenuJournalSheet({
    super.key,
    required this.entries,
  });

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Material(
          color: ThemePalette.surfacePanel(context),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusMd),
            ),
            side: BorderSide(color: ThemePalette.border(context)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Text(
                      'journalTitle'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: ThemePalette.border(context)),
              Expanded(
                child: entries.isEmpty
                    ? Center(child: Text('journalEmpty'.tr()))
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        itemCount: entries.length,
                        separatorBuilder: (context, index) =>
                            Divider(color: ThemePalette.border(context)),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.summary,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                '${entry.signature} · ${DateFormat.yMMMd().add_Hm().format(entry.timestamp)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: ThemePalette.onSurfaceMuted(
                                        context,
                                      ),
                                    ),
                              ),
                              if (entry.fieldChanges.isNotEmpty)
                                ...entry.fieldChanges.map(
                                  (change) => Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.xxs,
                                    ),
                                    child: Text(
                                      '${change.field}: ${change.oldValue} → ${change.newValue}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ),
                            ],
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
