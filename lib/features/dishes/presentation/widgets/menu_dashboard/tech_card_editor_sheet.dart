import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/di/session_holder.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/widgets/app_flushbar.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/domain/tech_card_draft.dart';
import 'package:mezzome/features/dishes/presentation/blocs/menu_dashboard_cubit.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/tech_card_editor_panel.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/tech_card_history_sheet.dart';

/// Bottom sheet с редактором техкарты.
class TechCardEditorSheet extends StatelessWidget {
  const TechCardEditorSheet({
    super.key,
    required this.draft,
    required this.signature,
    required this.showFinancials,
    required this.onChanged,
    required this.onRollback,
    required this.onSaveAndSign,
    required this.onClose,
    this.onShowHistory,
    this.onPullFromDish,
    this.selfApprove = false,
  });

  final TechCardDraft draft;
  final String signature;
  final bool showFinancials;
  final ValueChanged<TechCardDraft> onChanged;
  final VoidCallback onRollback;
  final Future<void> Function() onSaveAndSign;
  final VoidCallback onClose;
  final VoidCallback? onShowHistory;
  final Future<void> Function()? onPullFromDish;
  final bool selfApprove;

  static Future<void> show(
    BuildContext context, {
    required String signature,
    required bool showFinancials,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        final sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.92;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SizedBox(
            height: sheetHeight,
            child: BlocBuilder<MenuDashboardCubit, MenuDashboardState>(
              bloc: sl<MenuDashboardCubit>(),
              builder: (context, dashboard) {
                final draft = dashboard.editorDraft;
                if (draft == null) {
                  return const SizedBox.shrink();
                }

                final notifier = sl<MenuDashboardCubit>();

                // Шеф подтверждает правки техкарты сам (save + self-approve),
                // без отправки на согласование.
                final isChef = sl<SessionHolder>().role == UserRole.chef;

                return TechCardEditorSheet(
                  draft: draft,
                  signature: signature,
                  showFinancials: showFinancials,
                  selfApprove: isChef,
                  // История версий доступна только для сохранённой техкарты.
                  onShowHistory: draft.id == null
                      ? null
                      : () => TechCardHistorySheet.show(
                            sheetContext,
                            cardId: draft.id!,
                            cardName: draft.name,
                          ),
                  onChanged: notifier.updateEditorDraft,
                  onRollback: notifier.rollbackEditor,
                  // Подтяжка ингредиентов блюда доступна, только если есть
                  // привязка к блюду и карта редактируется.
                  onPullFromDish:
                      (draft.menuItemId == null || draft.readOnly)
                          ? null
                          : () async {
                              final result = await notifier.pullDishIngredients();
                              if (!sheetContext.mounted) return;
                              final message = result.error ?? result.notice;
                              if (message == null) return;
                              AppFlushbar.show(
                                sheetContext,
                                message,
                                isError: result.error != null,
                              );
                            },
                  onSaveAndSign: () async {
                    final result = await notifier.saveAndSign();
                    if (!sheetContext.mounted) {
                      return;
                    }
                    // Блокирующая ошибка (PLAN_NOT_EDITABLE) — оставляем лист
                    // открытым, чтобы пользователь увидел сообщение.
                    if (result.error != null) {
                      AppFlushbar.showError(sheetContext, result.error!);
                      return;
                    }
                    AppFlushbar.showSuccess(
                      sheetContext,
                      result.notice ?? 'techCardSavedToast'.tr(),
                    );
                    Navigator.of(sheetContext).pop();
                  },
                  onClose: () {
                    Navigator.of(sheetContext).pop();
                    notifier.closeEditor();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ThemePalette.border(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: TechCardEditorPanel(
              draft: draft,
              signature: signature,
              showFinancials: showFinancials,
              onChanged: onChanged,
              onClose: onClose,
              onRollback: onRollback,
              onSaveAndSign: onSaveAndSign,
              onShowHistory: onShowHistory,
              onPullFromDish: onPullFromDish,
              selfApprove: selfApprove,
            ),
          ),
        ],
      ),
    );
  }
}
