import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/data/repository/dishes_repository.dart';

/// Очередь утверждения производственных планов (только роль supervisor).
/// Данные: `GET /supervisor/production-plans?date=...`; решения —
/// approve / conditional-approve / reject.
class SupervisorPlansScreen extends ConsumerStatefulWidget {
  const SupervisorPlansScreen({super.key});

  @override
  ConsumerState<SupervisorPlansScreen> createState() =>
      _SupervisorPlansScreenState();
}

class _SupervisorPlansScreenState
    extends ConsumerState<SupervisorPlansScreen> {
  DateTime _date = DateFormatUtil.today;
  bool _loading = true;
  String? _error;
  List<ProductionPlanListItem> _plans = const [];

  static const _decided = {
    'approved',
    'conditional_approved',
    'conditionally_approved',
    'rejected',
    'cancelled',
    'canceled',
  };

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
      final plans =
          await ref.read(dishesRepositoryProvider).supervisorPlans(date: _date);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } on DioException catch (e) {
      appLogger.w('Supervisor plans load failed: ${e.response?.statusCode}');
      if (!mounted) return;
      setState(() {
        _error = e.response?.statusCode == 403
            ? 'supervisorPlansForbidden'.tr()
            : 'supervisorPlansError'.tr();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateFormatUtil.today.subtract(const Duration(days: 30)),
      lastDate: DateFormatUtil.today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      await _load();
    }
  }

  bool _isDecidable(String? status) =>
      !_decided.contains((status ?? '').toLowerCase());

  Future<String?> _askReason({
    required String title,
    required bool required,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(title: title, required: required),
    );
  }

  Future<void> _approve(ProductionPlanListItem plan, {bool force = false}) async {
    try {
      await ref.read(dishesRepositoryProvider).approvePlan(plan.id, force: force);
      _afterDecision('planApproved'.tr());
    } on DioException catch (e) {
      // План ещё не проверен шефом (draft) — обычный approve недоступен.
      // Предлагаем утвердить принудительно (force).
      if (!force && apiErrorCode(e) == 'INVALID_PLAN_STATUS') {
        if (!mounted) return;
        final action = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('planNeedsCheckTitle'.tr()),
            content: Text('planNeedsCheckBody'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('cancelButton'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('force'),
                child: Text('planForceApprove'.tr()),
              ),
            ],
          ),
        );
        if (action == 'force') {
          await _approve(plan, force: true);
        }
        return;
      }
      _decisionError(e);
    }
  }

  Future<void> _conditional(ProductionPlanListItem plan) async {
    final reason = await _askReason(
      title: 'planConditionalTitle'.tr(),
      required: true,
    );
    if (reason == null) return;
    try {
      await ref
          .read(dishesRepositoryProvider)
          .conditionalApprovePlan(plan.id, reason: reason);
      _afterDecision('planConditionalApproved'.tr());
    } on DioException catch (e) {
      _decisionError(e);
    }
  }

  Future<void> _reject(ProductionPlanListItem plan) async {
    final reason = await _askReason(
      title: 'planRejectTitle'.tr(),
      required: true,
    );
    if (reason == null) return;
    try {
      await ref.read(dishesRepositoryProvider).rejectPlan(plan.id, reason: reason);
      _afterDecision('planRejected'.tr());
    } on DioException catch (e) {
      _decisionError(e);
    }
  }

  void _afterDecision(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _load();
  }

  void _decisionError(DioException e) {
    appLogger.w('Plan decision failed: ${e.response?.data}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(apiErrorDetails(e) ?? 'planDecisionError'.tr()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('supervisorPlansTitle'.tr()),
        actions: [
          IconButton(
            tooltip: 'refreshTooltip'.tr(),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(DateFormatUtil.apiDate(_date)),
            ),
          ),
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
    if (_plans.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'supervisorPlansEmpty'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemePalette.onSurfaceMuted(context)),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: _plans.length,
      itemBuilder: (_, i) {
        final plan = _plans[i];
        return _PlanCard(
          plan: plan,
          decidable: _isDecidable(plan.status),
          onApprove: () => _approve(plan),
          onConditional: () => _conditional(plan),
          onReject: () => _reject(plan),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.decidable,
    required this.onApprove,
    required this.onConditional,
    required this.onReject,
  });

  final ProductionPlanListItem plan;
  final bool decidable;
  final VoidCallback onApprove;
  final VoidCallback onConditional;
  final VoidCallback onReject;

  ({Color color, String label}) _badge(BuildContext context) {
    final s = (plan.status ?? '').toLowerCase();
    if (s.contains('reject') || s.contains('cancel')) {
      return (color: AppColors.dangerRed, label: plan.status ?? '');
    }
    if (s.contains('approv')) {
      return (color: AppColors.profitGreen, label: plan.status ?? '');
    }
    return (color: AppColors.warningAmber, label: plan.status ?? 'draft');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = ThemePalette.onSurfaceMuted(context);
    final badge = _badge(context);
    final date = DateTime.tryParse(plan.plannedDate ?? '');

    final meta = <String>[
      if (plan.serviceType != null) plan.serviceType!,
      if (date != null) DateFormatUtil.apiDate(date),
      'planPortions'.tr(namedArgs: {'count': '${plan.totalPortions}'}),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'planNumber'.tr(namedArgs: {'id': '${plan.id}'}),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  badge.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: badge.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            meta.join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
          if (decidable) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, thickness: 0.5, color: ThemePalette.border(context)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text('planRejectShort'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dangerRed,
                      side: const BorderSide(color: AppColors.dangerRed),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('planApproveShort'.tr()),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onConditional,
                child: Text('planConditionalShort'.tr()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Диалог причины (для отклонения / условного утверждения).
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.required});

  final String title;
  final bool required;

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
    final canConfirm = !widget.required || _controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: 'planReasonLabel'.tr(),
          alignLabelWithHint: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancelButton'.tr()),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: Text('confirmButton'.tr()),
        ),
      ],
    );
  }
}
