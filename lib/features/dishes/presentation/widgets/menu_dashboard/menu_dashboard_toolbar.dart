import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';

class MenuDashboardToolbar extends StatelessWidget {
  const MenuDashboardToolbar({
    super.key,
    required this.journalCount,
    required this.onImportExcel,
    required this.onImportWord,
    required this.onExportExcel,
    required this.onExportWord,
    required this.onOpenJournal,
  });

  final int journalCount;
  final VoidCallback onImportExcel;
  final VoidCallback onImportWord;
  final VoidCallback onExportExcel;
  final VoidCallback onExportWord;
  final VoidCallback onOpenJournal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          _ToolbarButton(
            label: 'importExcel'.tr(),
            icon: Icons.upload_file,
            onPressed: onImportExcel,
          ),
          _ToolbarButton(
            label: 'importWord'.tr(),
            icon: Icons.upload_file,
            onPressed: onImportWord,
          ),
          _ToolbarButton(
            label: 'Excel',
            icon: Icons.table_chart,
            filled: true,
            onPressed: onExportExcel,
          ),
          _ToolbarButton(
            label: 'Word',
            icon: Icons.description,
            filled: true,
            onPressed: onExportWord,
          ),
          _ToolbarButton(
            label: 'journalButton'.tr(namedArgs: {'count': '$journalCount'}),
            icon: Icons.history,
            onPressed: onOpenJournal,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: ThemePalette.toolbarButtonStyle(context, filled: filled).merge(
        const ButtonStyle(
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
          ),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
