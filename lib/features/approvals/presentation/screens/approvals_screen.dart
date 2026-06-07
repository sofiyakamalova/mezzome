import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_colors_light.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/core/network/dio_provider.dart';
import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/presentation/providers/menu_dashboard_notifier.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/tech_card_editor_sheet.dart';

/// Фильтр очереди согласований.
enum _ApprovalFilter {
  pending,
  approved,
  rejected;

  String get label => switch (this) {
        _ApprovalFilter.pending => 'На согл.',
        _ApprovalFilter.approved => 'Утверждённые',
        _ApprovalFilter.rejected => 'Отклонённые',
      };

  IconData get icon => switch (this) {
        _ApprovalFilter.pending => Icons.hourglass_empty_rounded,
        _ApprovalFilter.approved => Icons.check_rounded,
        _ApprovalFilter.rejected => Icons.close_rounded,
      };
}

/// Нормализованная заявка для карточки (из tk-approvals или из техкарт).
class _ApprovalItem {
  const _ApprovalItem({
    this.id,
    this.name = '—',
    this.code = '',
    this.version,
    this.changeLevel,
    this.submittedAt,
    required this.status,
  });

  final int? id;
  final String name;
  final String code;
  final int? version;
  final String? changeLevel;
  final DateTime? submittedAt;
  final _ApprovalFilter status;
}

/// Очередь согласования техкарт (роль «manager»: manager/owner).
/// На согласовании — `GET /manager/tk-approvals` + approve/reject.
/// Утверждённые/отклонённые — `GET /chef/technical-cards?status=...`.
class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  _ApprovalFilter _filter = _ApprovalFilter.pending;
  bool _loading = true;
  String? _error;
  List<_ApprovalItem> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Один источник — очередь tk-approvals (отдаёт все статусы),
      // раскладываем по вкладкам клиентом.
      final all = await _loadQueue();
      final items = all.where((i) => i.status == _filter).toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      appLogger.w('Approvals load (${_filter.name}) failed (HTTP $status)');
      if (!mounted) return;
      setState(() {
        _error = status == 403
            ? 'Нет доступа (FORBIDDEN).\nСогласование техкарт доступно '
                'ролям manager / chef / owner.'
            : 'Не удалось загрузить (HTTP $status).';
        _loading = false;
      });
    }
  }

  /// Грузит очередь tk-approvals (содержит заявки во всех статусах)
  /// и нормализует каждую в [_ApprovalItem] с её реальным статусом.
  Future<List<_ApprovalItem>> _loadQueue() async {
    final dio = ref.read(dioProvider);
    final res = await dio.get<dynamic>('/manager/tk-approvals');
    appLogger.i('GET /manager/tk-approvals → 200');
    final data = res.data;
    final list = (data is Map && data['items'] is List)
        ? (data['items'] as List)
        : (data is List ? data : const []);
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map((m) {
          final statusStr = '${m['approval_status'] ?? m['status'] ?? ''}'
              .toLowerCase();
          final status = statusStr.contains('reject')
              ? _ApprovalFilter.rejected
              : (statusStr.contains('approv')
                  ? _ApprovalFilter.approved
                  : _ApprovalFilter.pending);
          return _ApprovalItem(
            id: m['id'] as int?,
            name: '${m['name'] ?? '—'}',
            code: '${m['code'] ?? ''}',
            version: m['version'] as int?,
            changeLevel: m['change_level'] as String?,
            submittedAt: DateTime.tryParse('${m['submitted_at'] ?? ''}'),
            status: status,
          );
        })
        .toList();
  }

  void _selectFilter(_ApprovalFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _load();
  }

  /// Спрашивает причину/комментарий и затем выполняет решение.
  /// Для отклонения причина обязательна (требование бэкенда: поле `reason`).
  Future<void> _confirmDecision(Object id, {required bool approve}) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(approve: approve),
    );
    // null — пользователь отменил диалог.
    if (reason == null) return;
    await _decide(id, approve: approve, reason: reason);
  }

  Future<void> _decide(
    Object id, {
    required bool approve,
    required String reason,
  }) async {
    final action = approve ? 'approve' : 'reject';
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post<dynamic>(
        '/manager/tk-approvals/$id/$action',
        data: <String, dynamic>{'reason': reason, 'comment': reason},
      );
      appLogger.i('POST /manager/tk-approvals/$id/$action → ${res.statusCode}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Утверждено' : 'Отклонено')),
      );
      await _load();
    } on DioException catch (e) {
      appLogger.w('Decision $action failed: ${e.response?.data}');
      if (!mounted) return;
      final details = apiErrorDetails(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(details ?? 'Ошибка: ${e.response?.statusCode}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Тап по заявке → открыть техкарту по её id для просмотра состава.
  Future<void> _review(_ApprovalItem item) async {
    final id = item.id;
    if (id == null) return;
    final notifier = ref.read(menuDashboardNotifierProvider.notifier);
    final session = ref.read(authSessionProvider).valueOrNull;
    final role = session?.role;
    final showFinancials = role != null && canSeeFinancials(role);
    final signature =
        session == null ? 'MEZZOME' : '${session.name} | MEZZOME';

    final cell = MenuGridCell(
      rowKey: 'tk_$id',
      rowLabel: item.code,
      date: DateFormatUtil.today,
      technicalCardId: id,
      dishName: item.name,
    );
    await notifier.selectCell(cell, requestContext: true);
    if (!mounted) return;
    if (ref.read(menuDashboardNotifierProvider).editorDraft == null) return;
    await TechCardEditorSheet.show(
      context,
      signature: signature,
      showFinancials: showFinancials,
    );
    notifier.closeEditor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Согласования'),
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
          _ApprovalTabs(selected: _filter, onSelected: _selectFilter),
          Expanded(
            child: RefreshIndicator(
              color: ThemePalette.accent(context),
              onRefresh: _load,
              child: _buildBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [Center(child: Text(_error!, textAlign: TextAlign.center))],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              switch (_filter) {
                _ApprovalFilter.pending => 'Заявок на согласование нет.',
                _ApprovalFilter.approved => 'Утверждённых техкарт нет.',
                _ApprovalFilter.rejected => 'Отклонённых техкарт нет.',
              },
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemePalette.onSurfaceMuted(context)),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        return _ApprovalCard(
          item: item,
          onReview: () => _review(item),
          onApprove: (id) => _confirmDecision(id, approve: true),
          onReject: (id) => _confirmDecision(id, approve: false),
        );
      },
    );
  }
}

/// Пилюли-фильтр: На согл. · Утверждённые · Отклонённые.
class _ApprovalTabs extends StatelessWidget {
  const _ApprovalTabs({required this.selected, required this.onSelected});

  final _ApprovalFilter selected;
  final ValueChanged<_ApprovalFilter> onSelected;

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
            for (final filter in _ApprovalFilter.values)
              Expanded(
                child: _ApprovalTab(
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

class _ApprovalTab extends StatelessWidget {
  const _ApprovalTab({
    required this.filter,
    required this.isActive,
    required this.onTap,
  });

  final _ApprovalFilter filter;
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
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? activeFill : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filter.icon,
              size: 15,
              color: isActive ? activeText : inactiveText,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                filter.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.item,
    required this.onReview,
    required this.onApprove,
    required this.onReject,
  });

  final _ApprovalItem item;
  final VoidCallback onReview;
  final ValueChanged<Object> onApprove;
  final ValueChanged<Object> onReject;

  static String _changeLevel(String? v) => switch ((v ?? '').toUpperCase()) {
        'PARAMETRIC' => 'Параметрическое',
        'COSMETIC' => 'Косметическое',
        'CRITICAL' || 'STRUCTURAL' => 'Критическое',
        _ => v ?? '',
      };

  static String _date(DateTime? value) {
    final d = value?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  ({Color color, String label}) _statusBadge() => switch (item.status) {
        _ApprovalFilter.pending => (
            color: AppColors.warningAmber,
            label: 'На согласовании'
          ),
        _ApprovalFilter.approved => (
            color: AppColors.profitGreen,
            label: 'Утверждено'
          ),
        _ApprovalFilter.rejected => (
            color: AppColors.dangerRed,
            label: 'Отклонено'
          ),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = ThemePalette.onSurfaceMuted(context);
    final id = item.id;
    final level = _changeLevel(item.changeLevel);
    final submitted = _date(item.submittedAt);
    final badge = _statusBadge();

    final metaParts = <String>[
      if (item.code.isNotEmpty) item.code,
      if (item.version != null) 'v${item.version}',
      if (level.isNotEmpty) level,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onReview,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _StatusPill(color: badge.color, label: badge.label),
                ],
              ),
              if (metaParts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    metaParts.join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ),
              if (submitted.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Отправлено: $submitted',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, thickness: 0.5, color: ThemePalette.border(context)),
              const SizedBox(height: AppSpacing.sm),
              if (item.status == _ApprovalFilter.pending && id != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onReject(id),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Отклонить'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerRed,
                          side: const BorderSide(color: AppColors.dangerRed),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onApprove(id),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Принять'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 16, color: muted),
                    const SizedBox(width: 6),
                    Text(
                      'Открыть техкарту',
                      style: theme.textTheme.labelMedium?.copyWith(color: muted),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, size: 18, color: muted),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Скруглённая статус-пилюля с полупрозрачной заливкой под цвет статуса.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

/// Диалог ввода причины/комментария к решению.
/// При отклонении причина обязательна (бэкенд требует поле `reason`),
/// при утверждении — необязательна.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.approve});

  final bool approve;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approve = widget.approve;
    final text = _controller.text.trim();
    // Для отклонения причина обязательна.
    final canConfirm = approve || text.isNotEmpty;

    return AlertDialog(
      title: Text(approve ? 'Утвердить техкарту' : 'Отклонить техкарту'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          labelText: approve ? 'Комментарий (необязательно)' : 'Причина',
          hintText: approve
              ? 'Например: согласовано'
              : 'Укажите причину отклонения',
          alignLabelWithHint: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          style: approve
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: AppColors.dangerRed,
                ),
          child: Text(approve ? 'Принять' : 'Отклонить'),
        ),
      ],
    );
  }
}
