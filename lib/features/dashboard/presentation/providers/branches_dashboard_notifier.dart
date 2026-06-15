import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dashboard/data/models/branch_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/expenses_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/repository/dashboard_repository.dart';

/// Карточка P&L одного объекта (филиала) — склейка строки `branches` и
/// расходов филиала из `expenses.by_branch` (гайд §7 + §8).
class ObjectFinance {
  const ObjectFinance({
    required this.id,
    required this.name,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.grossMarginPct,
    required this.expensesByCategory,
    required this.expensesTotal,
    required this.netProfit,
    required this.ordersCount,
    this.unallocatedOpex,
  });

  final int id;
  final String name;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double grossMarginPct;

  /// Построчная расшифровка расходов: `category -> amount` (ЗП, электричество…).
  final Map<String, double> expensesByCategory;
  final double expensesTotal;
  final double netProfit;
  final int ordersCount;

  /// Только для агрегата «All»: нераспределённый OPEX (строка-предупреждение).
  final double? unallocatedOpex;

  bool get isAll => id == _allId;
  static const int _allId = -1;
}

/// Состояние дашборда «Объекты»: список карточек + выбранный чип объекта.
class BranchesDashboardData {
  const BranchesDashboardData({
    required this.objects,
    required this.canViewMoney,
    required this.selectedId,
  });

  /// Все объекты (включая агрегат «All» первым элементом).
  final List<ObjectFinance> objects;
  final bool canViewMoney;

  /// `null` = выбран «All».
  final int? selectedId;

  /// Карточки под выбранный чип: при «All» показываем только агрегат,
  /// при выбранном объекте — только его.
  List<ObjectFinance> get visible {
    if (selectedId == null) {
      return objects.where((o) => o.isAll).toList();
    }
    return objects.where((o) => o.id == selectedId).toList();
  }

  BranchesDashboardData copyWith({int? selectedId, bool clearSelected = false}) {
    return BranchesDashboardData(
      objects: objects,
      canViewMoney: canViewMoney,
      selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
    );
  }
}

/// Дашборд «Объекты» (P&L по Catering 1/2/3). Период day/week/month/year,
/// общий с экраном «Обзор» паттерн. Данные держим при смене периода
/// (`copyWithPrevious`), чтобы не «моргало».
class BranchesDashboardNotifier
    extends AsyncNotifier<BranchesDashboardData> {
  String _period = 'week';
  late final String _date = DateFormatUtil.apiDate(DateFormatUtil.today);
  int? _selectedId;

  String get period => _period;
  int? get selectedId => _selectedId;

  @override
  Future<BranchesDashboardData> build() => _load();

  Future<BranchesDashboardData> _load() async {
    final repo = ref.read(dashboardRepositoryProvider);
    final results = await Future.wait([
      repo.fetchBranches(period: _period, date: _date),
      repo.fetchExpenses(period: _period, date: _date),
    ]);
    final branches = results[0] as BranchDashboard;
    final expenses = results[1] as ExpensesDashboardModel;
    return _merge(branches, expenses);
  }

  BranchesDashboardData _merge(
    BranchDashboard branches,
    ExpensesDashboardModel expenses,
  ) {
    final expByBranch = <int, ExpensesByBranch>{
      for (final e in expenses.byBranch) e.branchId: e,
    };

    final objects = <ObjectFinance>[];

    // Агрегат «All» — из totals. Полную разбивку расходов берём из
    // верхнеуровневого by_category (включает и аллоцированные, и
    // нераспределённые расходы — напр. зарплату); сумма = opex_total.
    // by_branch содержит только аллоцированную часть, поэтому для «All»
    // не годится. unallocatedOpex показываем справочной строкой «в т.ч.».
    final t = branches.totals;
    final allExpenses = Map<String, double>.from(expenses.byCategory);
    final allExpensesTotal = t.opexTotal ?? expenses.total;
    objects.add(
      ObjectFinance(
        id: ObjectFinance._allId,
        name: '',
        revenue: t.revenue,
        cogs: t.cost,
        grossProfit: t.grossProfit,
        grossMarginPct: t.grossMarginPct,
        expensesByCategory: allExpenses,
        expensesTotal: allExpensesTotal,
        netProfit: t.netProfit ?? (t.revenue - t.cost - allExpensesTotal),
        ordersCount: branches.branches.fold(0, (s, b) => s + b.ordersCount),
        unallocatedOpex: t.unallocatedOpex,
      ),
    );

    for (final b in branches.branches) {
      final exp = expByBranch[b.id];
      final byCategory = exp?.byCategory ?? const <String, double>{};
      final expensesTotal = b.opexTotal ?? exp?.total ?? 0;
      objects.add(
        ObjectFinance(
          id: b.id,
          name: b.name.isNotEmpty ? b.name : b.shortLabel,
          revenue: b.revenue,
          cogs: b.cost,
          grossProfit: b.grossProfit,
          grossMarginPct: b.grossMarginPct,
          expensesByCategory: byCategory,
          expensesTotal: expensesTotal,
          netProfit: b.netProfit ?? (b.revenue - b.cost - expensesTotal),
          ordersCount: b.ordersCount,
        ),
      );
    }

    // Сбрасываем выбор, если объект исчез из нового периода.
    if (_selectedId != null &&
        !branches.branches.any((b) => b.id == _selectedId)) {
      _selectedId = null;
    }

    return BranchesDashboardData(
      objects: objects,
      canViewMoney: branches.canViewMoney,
      selectedId: _selectedId,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading<BranchesDashboardData>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<void> setPeriod(String period) async {
    if (period == _period) return;
    _period = period;
    state = const AsyncLoading<BranchesDashboardData>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  /// Выбор чипа объекта. `null` = «All». Не дёргает сеть — фильтрует локально.
  void setBranch(int? id) {
    if (id == _selectedId) return;
    _selectedId = id;
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(selectedId: id, clearSelected: id == null),
      );
    }
  }
}

final branchesDashboardNotifierProvider =
    AsyncNotifierProvider<BranchesDashboardNotifier, BranchesDashboardData>(
  BranchesDashboardNotifier.new,
);
