import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/features/dishes/data/api/production_plans_api.dart';
import 'package:mezzome/features/dishes/data/api/technical_cards_api.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';
import 'package:mezzome/features/dishes/presentation/blocs/tech_card_cubit.dart';

/// «Производственная карта» = техкарта (норматив) × порции (план) + факт (весы).
/// Открывается по тапу на блюдо в меню. Логика/вёрстка — из макета заказчика,
/// данные реальные (техкарта блюда), цвета — тема приложения. Расчёт на клиенте
/// (позже подменим на серверный `/preview` + `/plan-vs-actual`).
class ProductionCardScreen extends StatefulWidget {
  const ProductionCardScreen({
    super.key,
    required this.item,
    this.date,
    this.onEdit,
  });

  final ProductionPlanGridCellItem item;
  final DateTime? date;

  /// Открыть редактор нормативной техкарты (кнопка-карандаш в аппбаре).
  final VoidCallback? onEdit;

  static Future<void> open(
    BuildContext context, {
    required ProductionPlanGridCellItem item,
    DateTime? date,
    VoidCallback? onEdit,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProductionCardScreen(item: item, date: date, onEdit: onEdit),
      ),
    );
  }

  @override
  State<ProductionCardScreen> createState() => _ProductionCardScreenState();
}

const _normUgarka = 0.30; // нормативная ужарка нетто→выход
const _equipment = [
  'Варочный котёл',
  'Пароконвектомат',
  'Плита',
  'Жарочная поверхность',
  'Сковорода',
  'Гриль',
  'Фритюр',
];
const _methods = ['Тушение', 'Варка', 'Жарка', 'Запекание'];

String _fmt(num n, [int d = 0]) {
  final v = n.isFinite ? n : 0;
  return NumberFormat.decimalPatternDigits(locale: 'ru_RU', decimalDigits: d)
      .format(v);
}

String _pct(num n, [int d = 1]) => '${_fmt(n * 100, d)}%';

/// Коэффициент перевода единицы в кг/л для наглядных колонок.
double _unitFactor(String? unit) {
  switch ((unit ?? '').toLowerCase()) {
    case 'gr':
    case 'г':
    case 'ml':
    case 'мл':
      return 0.001;
    default:
      return 1; // kg, l, pieces — как есть
  }
}

class _ProductionCardScreenState extends State<ProductionCardScreen> {
  late final TechCardCubit _cubit = sl<TechCardCubit>()..load(widget.item);

  bool _inited = false;

  // ── Нормативная рецептура на 1 порцию (из техкарты) ──
  List<_Ing> _recipe = const [];
  int _basePortions = 1;
  String _dishName = '';
  String _code = '';
  String _meal = '';

  // ── Редактируемое состояние плана ──
  int _portions = 1;
  late DateTime _cookDate = widget.date ?? DateTime.now();
  String _method = 'Тушение';
  final Set<String> _equip = {'Варочный котёл'};
  double _temp = 95, _time = 90, _humidity = 60;
  String _actualOutput = '';
  bool _liquidEnabled = false;
  double _liquidBrutto = 60, _liquidUparka = 0.15;
  final Map<String, double> _prices = {};
  String _notes = '';
  final List<Map<String, String>> _log = [];

  DateTime? _savedAt;
  bool _dirty = false;
  int? _cardId;

  final _portionsCtrl = TextEditingController();
  final _actualCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String get _dateIso => DateFormat('yyyy-MM-dd').format(_cookDate);
  String _storeKey() => 'mezzome:prodcard:${_cardId ?? 0}:$_dateIso';

  @override
  void dispose() {
    _debounce?.cancel();
    _cubit.close();
    _portionsCtrl.dispose();
    _actualCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _initFromCard(TechnicalCardModel card) {
    _cardId = card.id;
    _dishName = card.name;
    _cardName = card.name;
    _categoryId = card.categoryId;
    _outputPerPortion = card.outputPerPortion;
    _outputUnit = card.outputUnit;
    _halal = card.halalRequired;
    _code = 'TC-${card.id}';
    _meal = widget.item.categoryName ?? card.categoryName ?? '';
    _basePortions =
        card.basePortions > 0 ? card.basePortions.round() : 1;
    _portions = widget.item.plannedPortions > 0
        ? widget.item.plannedPortions
        : _basePortions;

    _recipe = [
      for (var i = 0; i < card.ingredients.length; i++)
        _ingFrom(card.ingredients[i], i, _basePortions),
    ];
    for (final ing in _recipe) {
      _prices[ing.key] = ing.price;
    }

    _portionsCtrl.text = '$_portions';
    _loadSaved();
    _schedulePreview();
    _loadPlanVsActual();
  }

  /// План/факт по позиции плана (выход/потери/факт с весов). Пока бэк не отдаёт
  /// — 404/пусто → null, работает fallback (output=netto, loss=100−yield).
  Future<void> _loadPlanVsActual() async {
    final planItemId = widget.item.planItemId;
    if (planItemId == null) return;
    try {
      final res =
          await sl<ProductionPlansApi>().getPlanItemPlanVsActual(planItemId);
      final pva = _PlanVsActual.tryParse(res);
      if (mounted) setState(() => _pva = pva);
    } catch (e) {
      appLogger.i('plan-vs-actual not available yet: $e');
    }
  }

  // ── Серверный расчёт КБЖУ/аллергенов/себестоимости (preview) ──
  _Preview? _preview;
  bool _previewLoading = false;
  Timer? _debounce;

  // ── План/факт с производства (plan-vs-actual) ──
  _PlanVsActual? _pva;
  String? _cardName;
  int? _categoryId;
  double _outputPerPortion = 0;
  String _outputUnit = 'g';
  bool _halal = false;

  /// Дебаунс — чтобы степпер порций не дёргал сеть на каждый клик.
  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _runPreview);
  }

  /// preview не масштабирует сам: brutto трактует как итог на base_portions.
  /// Чтобы получить N порций — шлём ингредиенты × N и base_portions = N.
  Future<void> _runPreview() async {
    if (_recipe.isEmpty || _portions <= 0) return;
    final n = _portions;
    final body = <String, dynamic>{
      'name': _cardName ?? _dishName,
      if (_categoryId != null) 'category_id': _categoryId,
      'base_portions': n,
      'output_per_portion': _outputPerPortion,
      'output_unit': _outputUnit,
      'halal_required': _halal,
      'ingredients': [
        for (var i = 0; i < _recipe.length; i++)
          {
            'ingredient_id': _recipe[i].id,
            'brutto': _recipe[i].bruttoPP * n,
            'netto': _recipe[i].nettoPP * n,
            'sort_order': i,
          },
      ],
    };
    setState(() => _previewLoading = true);
    try {
      final res = await sl<TechnicalCardsApi>().previewTechnicalCard(body);
      final p = _Preview.tryParse(res, portions: n);
      if (mounted) {
        setState(() {
          _preview = p;
          _previewLoading = false;
        });
      }
    } catch (e) {
      appLogger.w('preview failed: $e');
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  _Ing _ingFrom(TechnicalCardIngredientModel m, int i, int base) {
    final perBrutto = base > 0 ? m.brutto / base : m.brutto;
    final perNetto =
        m.nettoPerPortion ?? (base > 0 ? m.netto / base : m.netto);
    final cookLoss = m.cookingLossCoefficient ?? 0;
    final perOutput = perNetto * (1 - cookLoss);
    return _Ing(
      key: '$i',
      id: m.ingredientId,
      name: m.ingredientName ?? '#${m.ingredientId ?? i}',
      unit: m.unit,
      bruttoPP: perBrutto,
      nettoPP: perNetto,
      outputPP: perOutput,
      price: m.costPerUnit,
    );
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey());
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _portions = (m['portions'] as num?)?.toInt() ?? _portions;
        _method = m['method'] as String? ?? _method;
        _equip
          ..clear()
          ..addAll((m['equipment'] as List?)?.cast<String>() ?? _equip);
        _temp = (m['temp'] as num?)?.toDouble() ?? _temp;
        _time = (m['time'] as num?)?.toDouble() ?? _time;
        _humidity = (m['humidity'] as num?)?.toDouble() ?? _humidity;
        _actualOutput = m['actualOutput'] as String? ?? '';
        _liquidEnabled = m['liquidEnabled'] as bool? ?? false;
        _liquidBrutto = (m['liquidBrutto'] as num?)?.toDouble() ?? _liquidBrutto;
        _liquidUparka = (m['liquidUparka'] as num?)?.toDouble() ?? _liquidUparka;
        _notes = m['notes'] as String? ?? '';
        final p = m['prices'] as Map<String, dynamic>?;
        if (p != null) {
          for (final e in p.entries) {
            _prices[e.key] = (e.value as num).toDouble();
          }
        }
        final log = m['log'] as List?;
        if (log != null) {
          _log
            ..clear()
            ..addAll(log.map((e) => (e as Map).cast<String, String>()));
        }
        _portionsCtrl.text = '$_portions';
        _actualCtrl.text = _actualOutput;
        _notesCtrl.text = _notes;
      });
    } catch (_) {/* нет сохранённого плана — стартуем с норматива */}
  }

  Future<void> _save() async {
    final now = DateTime.now();
    _log.insert(0, {
      't': now.toIso8601String(),
      'text': 'План сохранён · $_portions порц.',
    });
    if (_log.length > 20) _log.removeRange(20, _log.length);
    final data = {
      'portions': _portions,
      'method': _method,
      'equipment': _equip.toList(),
      'temp': _temp,
      'time': _time,
      'humidity': _humidity,
      'actualOutput': _actualOutput,
      'liquidEnabled': _liquidEnabled,
      'liquidBrutto': _liquidBrutto,
      'liquidUparka': _liquidUparka,
      'prices': _prices,
      'notes': _notes,
      'log': _log,
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeKey(), jsonEncode(data));
      setState(() {
        _savedAt = now;
        _dirty = false;
      });
    } catch (_) {
      setState(() => _savedAt = null);
    }
  }

  void _setPortions(int v, {bool syncCtrl = true}) {
    final n = v < 0 ? 0 : v;
    setState(() {
      _portions = n;
      _dirty = true;
    });
    if (syncCtrl) _portionsCtrl.text = '$n';
    _schedulePreview();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _cookDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d != null) {
      setState(() {
        _cookDate = d;
        _dirty = true;
      });
    }
  }

  // ── Расчёт (зеркало useMemo, нормализация в кг) ──
  _Calc get _calc {
    final n = _portions < 0 ? 0 : _portions;
    final pv = _preview;
    final List<_Row> rows;
    if (pv != null && pv.rows.isNotEmpty) {
      // Источник истины — бэк: брутто/нетто/стоимость уже на N порций.
      rows = [
        for (final pr in pv.rows)
          () {
            final f = _unitFactor(pr.unit);
            // «Выход» по ингредиенту: приоритет — loss% из plan-vs-actual,
            // иначе cooking_loss из preview, иначе netto (fallback бэкендера).
            final pvaIng = _pva?.byIngredient[pr.ingredientId];
            final lossFrac = pvaIng?.plannedLossPct != null
                ? pvaIng!.plannedLossPct! / 100
                : pr.cookLoss;
            return _Row(
              priceKey: null,
              name: pr.name,
              unit: pr.unit,
              bruttoKg: pr.brutto * f,
              nettoKg: pr.netto * f,
              outKg: pr.netto * (1 - lossFrac) * f,
              price: pr.costPerUnit,
              sum: pr.totalCost,
            );
          }(),
      ];
    } else {
      // Fallback (пока preview грузится/недоступен) — клиентская пропорция.
      rows = _recipe.map((r) {
        final f = _unitFactor(r.unit);
        final price = _prices[r.key] ?? r.price;
        return _Row(
          priceKey: r.key,
          name: r.name,
          unit: r.unit,
          bruttoKg: r.bruttoPP * n * f,
          nettoKg: r.nettoPP * n * f,
          outKg: r.outputPP * n * f,
          price: price,
          sum: r.bruttoPP * n * price,
        );
      }).toList();
    }

    var bruttoKg = rows.fold<double>(0, (a, r) => a + r.bruttoKg);
    var nettoKg = rows.fold<double>(0, (a, r) => a + r.nettoKg);
    var outKg = rows.fold<double>(0, (a, r) => a + r.outKg);
    final cost = pv != null && pv.rows.isNotEmpty
        ? pv.totalCost
        : rows.fold<double>(0, (a, r) => a + r.sum);

    _Liquid? liquid;
    if (_liquidEnabled) {
      final lb = _liquidBrutto * n / 1000;
      final lo = lb * (1 - _liquidUparka);
      liquid = _Liquid(lb, lb, lo);
      bruttoKg += lb;
      nettoKg += lb;
      outKg += lo;
    }

    final plateG = n > 0 ? outKg * 1000 / n : 0.0;
    final cleanLoss = bruttoKg > 0 ? (bruttoKg - nettoKg) / bruttoKg : 0.0;
    final ugarka = nettoKg > 0 ? (nettoKg - outKg) / nettoKg : 0.0;
    final totalLoss = bruttoKg > 0 ? (bruttoKg - outKg) / bruttoKg : 0.0;
    final yieldPct = bruttoKg > 0 ? outKg / bruttoKg : 0.0;
    final costPerPortion = n > 0 ? cost / n : 0.0;
    final costPerKg = outKg > 0 ? cost / outKg : 0.0;

    _Fact? fact;
    final actual = double.tryParse(_actualOutput.replaceAll(',', '.'));
    if (actual != null && actual > 0) {
      final actUgarka = nettoKg > 0 ? (nettoKg - actual) / nettoKg : 0.0;
      final devPp = (actUgarka - _normUgarka) * 100;
      final deltaKg = actual - outKg;
      var verdict = 'ok', label = 'Норма';
      if (devPp.abs() > 6) {
        verdict = 'bad';
        label = 'Расхождение';
      } else if (devPp.abs() > 3) {
        verdict = 'warn';
        label = 'Проверить';
      }
      fact = _Fact(actual, actUgarka, devPp, deltaKg, verdict, label);
    }

    return _Calc(n, rows, liquid, bruttoKg, nettoKg, outKg, cost, plateG,
        cleanLoss, ugarka, totalLoss, yieldPct, costPerPortion, costPerKg, fact);
  }

  // ── Цвета темы ──
  Color get _accent => ThemePalette.accent(context);
  Color get _txt => ThemePalette.onSurface(context);
  Color get _dim => ThemePalette.onSurfaceMuted(context);
  Color get _dim2 => ThemePalette.onSurfaceMuted(context).withValues(alpha: 0.6);
  Color get _line => ThemePalette.border(context);
  Color get _card => ThemePalette.surfaceCard(context);
  Color get _panel2 => ThemePalette.surfacePanel(context);
  Color get _green => AppColors.profitGreen;
  Color get _red => AppColors.dangerRed;
  Color _vColor(String v) =>
      v == 'bad' ? _red : (v == 'warn' ? AppColors.warningAmber : _green);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Производственная карта'),
        actions: [
          if (widget.onEdit != null)
            IconButton(
              tooltip: 'Редактировать техкарту',
              icon: const Icon(Icons.edit_outlined),
              onPressed: widget.onEdit,
            ),
          if (_savedAt != null && !_dirty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('✓ ${DateFormat('HH:mm').format(_savedAt!)}',
                    style: TextStyle(color: _green, fontSize: 12)),
              ),
            ),
        ],
      ),
      body: BlocBuilder<TechCardCubit, TechCardState>(
        bloc: _cubit,
        builder: (context, state) {
          if (state.status == TechCardStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final card = state.data?.card;
          if (card == null) {
            return Center(
              child: Text('Техкарта не найдена', style: TextStyle(color: _dim)),
            );
          }
          if (!_inited) {
            _inited = true;
            _initFromCard(card);
          }
          return _content();
        },
      ),
      floatingActionButton: _inited
          ? FloatingActionButton.extended(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить план'),
            )
          : null,
    );
  }

  Widget _content() {
    final c = _calc;
    return LayoutBuilder(builder: (context, cons) {
      final narrow = cons.maxWidth < 720;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dishHeader(c),
                const SizedBox(height: 16),
                _kpis(c, narrow),
                const SizedBox(height: 16),
                if (narrow)
                  Column(children: [
                    _leftColumn(c),
                    const SizedBox(height: 16),
                    _rightColumn(c),
                  ])
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 16, child: _leftColumn(c)),
                      const SizedBox(width: 16),
                      Expanded(flex: 10, child: _rightColumn(c)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Шапка блюда ──
  Widget _dishHeader(_Calc c) {
    return _panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusPill(),
          const SizedBox(height: 12),
          Text(_dishName,
              style: TextStyle(
                  color: _txt,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('ID: $_code', style: TextStyle(color: _dim, fontSize: 13)),
            if (_meal.isNotEmpty) _chip(_meal),
            Text('норматив × план', style: TextStyle(color: _dim, fontSize: 13)),
          ]),
          const SizedBox(height: 18),
          _planStrip(c),
        ],
      ),
    );
  }

  Widget _planStrip(_Calc c) {
    return Container(
      decoration: BoxDecoration(
        color: _panel2,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _miniLabel('Готовим на дату'),
            InkWell(
              onTap: _pickDate,
              child: Container(
                width: 160,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.event, size: 16, color: _dim),
                  const SizedBox(width: 8),
                  Text(DateFormat('dd.MM.yyyy').format(_cookDate),
                      style: TextStyle(color: _txt, fontSize: 14)),
                ]),
              ),
            ),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _miniLabel('Порций'),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _stepBtn('−', () => _setPortions(_portions - 10)),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _portionsCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _accent,
                      fontSize: 26,
                      fontWeight: FontWeight.w700),
                  decoration: _fieldDeco(),
                  onChanged: (v) =>
                      _setPortions(int.tryParse(v) ?? 0, syncCtrl: false),
                ),
              ),
              const SizedBox(width: 8),
              _stepBtn('+', () => _setPortions(_portions + 10)),
            ]),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _miniLabel('Целевой выход · на тарелке'),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_fmt(c.outKg, 1)} кг',
                    style: TextStyle(
                        color: _txt, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Text('·', style: TextStyle(color: _dim2)),
                const SizedBox(width: 10),
                Text('${_fmt(c.plateG)} г/порция',
                    style: TextStyle(color: _dim, fontSize: 15)),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  // ── KPI ──
  Widget _kpis(_Calc c, bool narrow) {
    // Себестоимость — с бэка (preview), если посчитана; иначе клиентская.
    final backendTotal = _preview?.totalCost;
    final costPP = backendTotal != null && c.n > 0
        ? backendTotal / c.n
        : c.costPerPortion;
    final foodCost = _preview?.foodCostPct;
    final cards = [
      _kpi('Себестоимость порции', '${_fmt(costPP)} ₸', accent: true),
      if (foodCost != null)
        _kpi('Food cost', _pct(foodCost / 100, 1))
      else
        _kpi('Себестоимость 1 кг', '${_fmt(c.costPerKg)} ₸'),
      _kpi('Сырьё на смену · брутто', '${_fmt(c.bruttoKg, 1)} кг'),
      _kpi('Выход готового', _pct(c.yieldPct, 0)),
    ];
    final cols = narrow ? 2 : 4;
    return LayoutBuilder(builder: (context, cons) {
      final w = (cons.maxWidth - 16 * (cols - 1)) / cols;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [for (final k in cards) SizedBox(width: w, child: k)],
      );
    });
  }

  Widget _leftColumn(_Calc c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _recipeSection(c),
          const SizedBox(height: 16),
          _techSection(),
        ],
      );

  Widget _rightColumn(_Calc c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _processSection(c),
          const SizedBox(height: 16),
          _nutritionSection(),
          const SizedBox(height: 16),
          _analyticsSection(c),
          const SizedBox(height: 16),
          _notesSection(),
        ],
      );

  // ── Рецептура ──
  Widget _recipeSection(_Calc c) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHead('Рецептура',
              trailing: Text(
                  _preview != null
                      ? '× ${c.n} порц. · с бэка'
                      : (_previewLoading
                          ? '× ${c.n} порц. · расчёт…'
                          : '× ${c.n} порц.'),
                  style: TextStyle(color: _dim, fontSize: 12))),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 520),
              child: _recipeTable(c),
            ),
          ),
          _liquidToggle(c),
        ],
      ),
    );
  }

  Widget _recipeTable(_Calc c) {
    const heads = [
      '№',
      'Продукт',
      'Брутто, кг',
      'Нетто, кг',
      'Выход, кг',
      'Цена ₸/ед',
      'Сумма, ₸'
    ];
    final hs = TextStyle(
        color: _dim, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5);
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(28),
        1: FlexColumnWidth(2.4),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1.2),
        5: FixedColumnWidth(86),
        6: FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          for (var i = 0; i < heads.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Text(heads[i],
                  textAlign: i >= 2 ? TextAlign.right : TextAlign.left,
                  style: hs),
            ),
        ]),
        for (var i = 0; i < c.rows.length; i++) _recipeRow(c.rows[i], i),
        if (_liquidEnabled && c.liquid != null) _liquidRow(c.liquid!),
        _totalRow(c),
      ],
    );
  }

  TableRow _recipeRow(_Row r, int i) {
    return TableRow(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _line))),
      children: [
        _cell(Text('${i + 1}', style: TextStyle(color: _dim2, fontSize: 13))),
        _cell(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.name, style: TextStyle(color: _txt, fontSize: 13)),
          if (r.unit != null)
            Text('ед: ${r.unit}', style: TextStyle(color: _dim2, fontSize: 11)),
        ])),
        _numCell(_fmt(r.bruttoKg, 1)),
        _numCell(_fmt(r.nettoKg, 1), color: _dim),
        _numCell(_fmt(r.outKg, 1), color: _accent),
        r.priceKey != null
            ? _cell(_priceField(r))
            : _numCell(_fmt(r.price)),
        _numCell(_fmt(r.sum), weight: FontWeight.w600),
      ],
    );
  }

  TableRow _liquidRow(_Liquid l) {
    return TableRow(
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.05),
        border: Border(top: BorderSide(color: _line)),
      ),
      children: [
        _cell(Text('+', style: TextStyle(color: _dim2, fontSize: 13))),
        _cell(Text('Бульон / вода', style: TextStyle(color: _txt, fontSize: 13))),
        _numCell(_fmt(l.bruttoKg, 1)),
        _numCell(_fmt(l.nettoKg, 1), color: _dim),
        _numCell(_fmt(l.outKg, 1), color: _accent),
        _numCell('—', color: _dim2),
        _numCell('0', color: _dim2),
      ],
    );
  }

  TableRow _totalRow(_Calc c) {
    return TableRow(
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: _line, width: 2))),
      children: [
        _cell(Text('ИТОГО',
            style: TextStyle(
                color: _txt, fontSize: 13, fontWeight: FontWeight.w700))),
        _cell(const SizedBox()),
        _numCell(_fmt(c.bruttoKg, 1), weight: FontWeight.w700),
        _numCell(_fmt(c.nettoKg, 1), weight: FontWeight.w700, color: _dim),
        _numCell(_fmt(c.outKg, 1), weight: FontWeight.w700, color: _accent),
        _cell(const SizedBox()),
        _numCell(_fmt(c.cost), weight: FontWeight.w800, color: _accent),
      ],
    );
  }

  Widget _priceField(_Row r) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 78,
        child: TextField(
          controller: TextEditingController(text: _fmt(r.price))
            ..selection = const TextSelection.collapsed(offset: -1),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          style: TextStyle(color: _txt, fontSize: 13),
          decoration: _fieldDeco(dense: true),
          onChanged: (v) {
            _prices[r.priceKey!] =
                double.tryParse(v.replaceAll(' ', '').replaceAll(',', '.')) ??
                    r.price;
            setState(() => _dirty = true);
          },
        ),
      ),
    );
  }

  Widget _liquidToggle(_Calc c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _line))),
      child: Row(children: [
        Checkbox(
          value: _liquidEnabled,
          activeColor: _accent,
          onChanged: (v) => setState(() {
            _liquidEnabled = v ?? false;
            _dirty = true;
          }),
        ),
        Expanded(
          child: Text('Добавить бульон / воду',
              style: TextStyle(color: _txt, fontSize: 13)),
        ),
        if (_liquidEnabled) ...[
          Text('г/порц.', style: TextStyle(color: _dim, fontSize: 12)),
          const SizedBox(width: 6),
          _smallNum(_liquidBrutto, (v) => _liquidBrutto = v, width: 60),
          const SizedBox(width: 8),
          Text('упарка%', style: TextStyle(color: _dim, fontSize: 12)),
          const SizedBox(width: 6),
          _smallNum(_liquidUparka * 100, (v) => _liquidUparka = v / 100,
              width: 52),
        ],
      ]),
    );
  }

  // ── Технология ──
  Widget _techSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHead('Технология приготовления'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _miniLabel('Метод'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in _methods)
                  _selChip(m, _method == m, () => setState(() {
                        _method = m;
                        _dirty = true;
                      })),
              ]),
              const SizedBox(height: 18),
              _miniLabel('Оборудование'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final eq in _equipment)
                  _selChip(eq, _equip.contains(eq), () {
                    setState(() {
                      _equip.contains(eq) ? _equip.remove(eq) : _equip.add(eq);
                      _dirty = true;
                    });
                  }),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                    child: _paramField(
                        'Температура, °C', _temp, (v) => _temp = v)),
                const SizedBox(width: 12),
                Expanded(
                    child: _paramField('Время, мин', _time, (v) => _time = v)),
                const SizedBox(width: 12),
                Expanded(
                    child: _paramField(
                        'Влажность, %', _humidity, (v) => _humidity = v)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Контроль процесса ──
  Widget _processSection(_Calc c) {
    final f = c.fact;
    final pva = _pva;
    final pvaActual = pva != null && pva.hasActual;

    // Вердикт по отклонению потерь (факт − план), в п.п.
    double? pvaDev;
    var pvaVerdict = 'ok';
    if (pvaActual && pva.actualLossPct != null && pva.plannedLossPct != null) {
      pvaDev = pva.actualLossPct! - pva.plannedLossPct!;
      if (pvaDev.abs() > 6) {
        pvaVerdict = 'bad';
      } else if (pvaDev.abs() > 3) {
        pvaVerdict = 'warn';
      }
    }

    final factStr = pvaActual
        ? '${_fmt(pva.actualOutputTotal!, 1)} кг'
        : (f != null ? '${_fmt(f.actual, 1)} кг' : null);
    final factColor = pvaActual
        ? _vColor(pvaVerdict)
        : (f != null ? _vColor(f.verdict) : null);

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHead('Контроль процесса',
              trailing: Text(pvaActual ? 'факт с весов' : 'масса не врёт',
                  style: TextStyle(color: _dim2, fontSize: 11))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _zone('S0', 'Склад · списание (брутто)',
                  '${_fmt(c.bruttoKg, 1)} кг'),
              _zone('S1', 'После чистки (нетто)', '${_fmt(c.nettoKg, 1)} кг'),
              _zone('S2–S3', 'Котёл · готовый выход', '${_fmt(c.outKg, 1)} кг',
                  fact: factStr, factColor: factColor),
              _zone('S4', 'Тарелка × порций', '${_fmt(c.outKg, 1)} кг', last: true),
              const SizedBox(height: 16),
              Divider(height: 1, color: _line),
              const SizedBox(height: 16),
              if (pvaActual)
                ..._backendFact(pva, pvaDev, pvaVerdict)
              else
                ..._manualFact(f),
            ]),
          ),
        ],
      ),
    );
  }

  /// Факт с производства (plan-vs-actual) — реальные веса, без ручного ввода.
  List<Widget> _backendFact(_PlanVsActual p, double? dev, String verdict) {
    return [
      Row(children: [
        Expanded(child: _miniLabel('Факт с производства (весы)')),
        if (dev != null)
          _verdictPill(
              verdict == 'bad'
                  ? 'Расхождение'
                  : (verdict == 'warn' ? 'Проверить' : 'Норма'),
              _vColor(verdict)),
      ]),
      Row(children: [
        Expanded(
            child: _factRow('Порций факт', '${p.actualPortions ?? '—'}')),
        Expanded(
            child: _factRow('План', '${p.plannedPortions ?? _portions}',
                dim: true)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
            child: _factRow('Выход факт',
                '${_fmt(p.actualOutputTotal ?? 0, 1)} кг')),
        Expanded(
            child: _factRow(
                'План', '${_fmt(p.plannedOutputTotal ?? 0, 1)} кг',
                dim: true)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
            child: _factRow(
                'Потери факт', '${_fmt(p.actualLossPct ?? 0, 1)}%')),
        Expanded(
            child: _factRow('План', '${_fmt(p.plannedLossPct ?? 0, 1)}%',
                dim: true)),
      ]),
      if (dev != null) ...[
        const SizedBox(height: 6),
        _factRow('Отклонение потерь',
            '${dev >= 0 ? '+' : ''}${_fmt(dev, 1)} п.п.',
            color: _vColor(verdict)),
      ],
    ];
  }

  /// Ручной ввод факта (пока plan-vs-actual не отдаёт факт по этому блюду).
  List<Widget> _manualFact(_Fact? f) {
    return [
      _miniLabel('Факт. выход после т/о — взвесить котёл'),
      Row(children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: _actualCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: _txt, fontSize: 18),
            decoration: _fieldDeco(hint: '0.0'),
            onChanged: (v) => setState(() {
              _actualOutput = v;
              _dirty = true;
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text('кг', style: TextStyle(color: _dim)),
        const SizedBox(width: 8),
        if (f != null) _verdictPill(f.label, _vColor(f.verdict)),
      ]),
      if (f != null) ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _factRow('Факт. ужарка', _pct(f.actUgarka))),
          Expanded(
              child: _factRow('Норматив', _pct(_normUgarka, 0), dim: true)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: _factRow('Отклонение',
                  '${f.devPp >= 0 ? '+' : ''}${_fmt(f.devPp, 1)} п.п.',
                  color: _vColor(f.verdict))),
          Expanded(
              child: _factRow('Δ масса',
                  '${f.deltaKg >= 0 ? '+' : ''}${_fmt(f.deltaKg, 1)} кг',
                  color: _vColor(f.verdict))),
        ]),
      ],
    ];
  }

  Widget _analyticsSection(_Calc c) {
    return _panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHead('Аналитика'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _ana('Потери чистки (брутто→нетто)', _pct(c.cleanLoss)),
            _ana('Ужарка / упарка (нетто→выход)', _pct(c.ugarka)),
            _ana('Общие потери (брутто→тарелка)', _pct(c.totalLoss)),
            _ana('Выход готовой продукции', _pct(c.yieldPct), accent: true),
          ]),
        ),
      ]),
    );
  }

  // ── КБЖУ и аллергены (с бэка, preview) ──
  static const _nutLabels = {
    'calories_kcal': 'Ккал',
    'protein_g': 'Белки, г',
    'fat_g': 'Жиры, г',
    'carbohydrates_g': 'Углеводы, г',
    'fiber_g': 'Клетчатка, г',
    'sodium_mg': 'Натрий, мг',
  };
  static const _allergenLabels = {
    'celery': 'Сельдерей',
    'milk': 'Молоко',
    'eggs': 'Яйца',
    'gluten': 'Глютен',
    'fish': 'Рыба',
    'soy': 'Соя',
    'nuts': 'Орехи',
    'tree_nuts': 'Орехи',
    'peanuts': 'Арахис',
    'sesame': 'Кунжут',
    'crustaceans': 'Ракообразные',
    'molluscs': 'Моллюски',
    'mustard': 'Горчица',
    'sulphites': 'Сульфиты',
    'lupin': 'Люпин',
  };

  Widget _nutritionSection() {
    final p = _preview;
    return _panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHead('КБЖУ и аллергены',
            trailing: _previewLoading
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('с бэка', style: TextStyle(color: _dim2, fontSize: 11))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Аллергены.
            _miniLabel('Аллергены'),
            if (p == null)
              Text('—', style: TextStyle(color: _dim))
            else if (p.allergens.isEmpty)
              Text('не указаны', style: TextStyle(color: _dim, fontSize: 13))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in p.allergens) _chip(_allergenLabels[a] ?? a),
              ]),
            const SizedBox(height: 16),
            // КБЖУ.
            Row(children: [
              Expanded(child: _miniLabel('КБЖУ')),
              Text('порция · всего',
                  style: TextStyle(color: _dim2, fontSize: 11)),
            ]),
            if (p == null)
              Text('—', style: TextStyle(color: _dim))
            else
              for (final e in _nutLabels.entries)
                _nutRow(e.value, p.nutritionPerPortion[e.key] ?? 0,
                    p.nutritionTotal[e.key] ?? 0),
          ]),
        ),
      ]),
    );
  }

  Widget _nutRow(String label, double perPortion, double total) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: _dim, fontSize: 13))),
          Text(_fmt(perPortion, 1),
              style: TextStyle(color: _txt, fontWeight: FontWeight.w600)),
          Text('  ·  ', style: TextStyle(color: _dim2)),
          Text(_fmt(total, 1), style: TextStyle(color: _dim, fontSize: 13)),
        ]),
      );

  Widget _notesSection() {
    return _panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHead('Заметки шефа'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _notesCtrl,
              maxLines: 4,
              style: TextStyle(color: _txt, fontSize: 13),
              decoration:
                  _fieldDeco(hint: 'Контрольное взвешивание, замены, замечания…'),
              onChanged: (v) => setState(() {
                _notes = v;
                _dirty = true;
              }),
            ),
            if (_log.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final l in _log)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Text(
                        DateFormat('dd.MM HH:mm')
                            .format(DateTime.parse(l['t']!)),
                        style: TextStyle(color: _dim2, fontSize: 11)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(l['text'] ?? '',
                            style: TextStyle(color: _dim, fontSize: 11))),
                  ]),
                ),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── Хелперы ──
  Widget _panel({required Widget child, EdgeInsets? padding}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _card,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _statusPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.12),
          border: Border.all(color: _green.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: _green, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text('Норматив × план',
              style: TextStyle(
                  color: _green, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _panel2,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(t, style: TextStyle(color: _dim, fontSize: 13)),
      );

  Widget _miniLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(t.toUpperCase(),
            style: TextStyle(
                color: _dim,
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600)),
      );

  Widget _stepBtn(String t, VoidCallback onTap) => SizedBox(
        width: 38,
        height: 44,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: _accent,
            side: BorderSide(color: _line),
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(t,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        ),
      );

  InputDecoration _fieldDeco({bool dense = false, String? hint}) =>
      InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(color: _dim2),
        contentPadding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 12, vertical: dense ? 6 : 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dense ? 8 : 10),
          borderSide: BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dense ? 8 : 10),
          borderSide: BorderSide(color: _accent),
        ),
      );

  Widget _kpi(String label, String value, {bool accent = false}) => _panel(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _miniLabel(label),
          Text(value,
              style: TextStyle(
                  color: accent ? _accent : _txt,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
        ]),
      );

  Widget _sectionHead(String title, {Widget? trailing}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: Row(children: [
          Text(title,
              style: TextStyle(
                  color: _txt, fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          ?trailing,
        ]),
      );

  Widget _cell(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: child,
      );

  Widget _numCell(String t, {Color? color, FontWeight? weight}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Text(t,
            textAlign: TextAlign.right,
            style: TextStyle(color: color ?? _txt, fontWeight: weight)),
      );

  Widget _smallNum(double value, ValueChanged<double> onChange,
      {double width = 60}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: TextEditingController(text: _fmt(value))
          ..selection = const TextSelection.collapsed(offset: -1),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        style: TextStyle(color: _txt, fontSize: 13),
        decoration: _fieldDeco(dense: true),
        onChanged: (v) {
          final p = double.tryParse(v.replaceAll(',', '.'));
          if (p != null) {
            setState(() {
              onChange(p);
              _dirty = true;
            });
          }
        },
      ),
    );
  }

  Widget _paramField(String label, double value, ValueChanged<double> onChange) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _miniLabel(label),
      TextField(
        controller: TextEditingController(text: _fmt(value))
          ..selection = const TextSelection.collapsed(offset: -1),
        keyboardType: TextInputType.number,
        style: TextStyle(color: _txt, fontSize: 18),
        decoration: _fieldDeco(),
        onChanged: (v) {
          final p = double.tryParse(v.replaceAll(',', '.'));
          if (p != null) {
            setState(() {
              onChange(p);
              _dirty = true;
            });
          }
        },
      ),
    ]);
  }

  Widget _selChip(String t, bool on, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: on ? _accent : _panel2,
            border: Border.all(color: on ? _accent : _line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(t,
              style: TextStyle(
                  color: on
                      ? (ThemePalette.isLight(context) ? Colors.white : Colors.black)
                      : _dim,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      );

  Widget _zone(String code, String name, String plan,
      {String? fact, Color? factColor, bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border:
              last ? null : Border(bottom: BorderSide(color: _line))),
      child: Row(children: [
        Container(
          constraints: const BoxConstraints(minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.1),
            border: Border.all(color: _accent.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(code,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _accent, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: TextStyle(color: _txt, fontSize: 13))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(plan, style: TextStyle(color: _txt, fontSize: 14)),
          if (fact != null)
            Text('факт $fact',
                style: TextStyle(color: factColor, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _verdictPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  Widget _factRow(String label, String value, {Color? color, bool dim = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: _dim2, fontSize: 12)),
      Text(value,
          style: TextStyle(
              color: color ?? (dim ? _dim : _txt),
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _ana(String label, String value, {bool accent = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: _dim, fontSize: 13))),
          Text(value,
              style: TextStyle(
                  color: accent ? _accent : _txt,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Структуры ──
class _Ing {
  const _Ing({
    required this.key,
    required this.id,
    required this.name,
    required this.unit,
    required this.bruttoPP,
    required this.nettoPP,
    required this.outputPP,
    required this.price,
  });
  final String key;
  final int? id;
  final String name;
  final String? unit;
  final double bruttoPP; // на 1 порцию, в ед. ингредиента
  final double nettoPP;
  final double outputPP;
  final double price; // ₸ за ед.
}

/// План/факт по ингредиенту (`plan-vs-actual`). Все поля optional — пока бэк
/// не отдаёт, остаются null и работает fallback.
class _PvaIng {
  _PvaIng({
    this.plannedOutput,
    this.actualOutput,
    this.plannedLossPct,
    this.actualLossPct,
    this.plannedNetto,
    this.actualNetto,
    this.varianceOutput,
  });
  final double? plannedOutput,
      actualOutput,
      plannedLossPct,
      actualLossPct,
      plannedNetto,
      actualNetto,
      varianceOutput;
}

/// План/факт позиции плана (`GET /production/plan-items/{id}/plan-vs-actual`).
class _PlanVsActual {
  _PlanVsActual({
    this.plannedPortions,
    this.actualPortions,
    this.plannedOutputTotal,
    this.actualOutputTotal,
    this.plannedLossPct,
    this.actualLossPct,
    this.plannedYieldPct,
    this.actualYieldPct,
    this.byIngredient = const {},
  });

  final int? plannedPortions, actualPortions;
  final double? plannedOutputTotal,
      actualOutputTotal,
      plannedLossPct,
      actualLossPct,
      plannedYieldPct,
      actualYieldPct;
  final Map<int, _PvaIng> byIngredient;

  bool get hasActual => actualOutputTotal != null && actualOutputTotal! > 0;

  static _PlanVsActual? tryParse(dynamic res) {
    if (res is! Map) return null;
    final m = res.map((k, v) => MapEntry('$k', v));
    double? dn(dynamic x) => x is num ? x.toDouble() : double.tryParse('$x');
    int? inn(dynamic x) => x is num ? x.toInt() : int.tryParse('$x');
    final s = (m['summary'] as Map?)?.map((k, v) => MapEntry('$k', v)) ?? const {};
    final by = <int, _PvaIng>{};
    final ings = m['ingredients'];
    if (ings is List) {
      for (final e in ings) {
        if (e is! Map) continue;
        final r = e.map((k, v) => MapEntry('$k', v));
        final id = inn(r['ingredient_id']);
        if (id == null) continue;
        by[id] = _PvaIng(
          plannedOutput: dn(r['planned_output']),
          actualOutput: dn(r['actual_output']),
          plannedLossPct: dn(r['planned_loss_pct']),
          actualLossPct: dn(r['actual_loss_pct']),
          plannedNetto: dn(r['planned_netto']),
          actualNetto: dn(r['actual_netto']),
          varianceOutput: dn(r['variance_output']),
        );
      }
    }
    return _PlanVsActual(
      plannedPortions: inn(m['planned_portions']),
      actualPortions: inn(m['actual_portions']),
      plannedOutputTotal: dn(s['planned_output_total']),
      actualOutputTotal: dn(s['actual_output_total']),
      plannedLossPct: dn(s['planned_loss_pct']),
      actualLossPct: dn(s['actual_loss_pct']),
      plannedYieldPct: dn(s['planned_yield_pct']),
      actualYieldPct: dn(s['actual_yield_pct']),
      byIngredient: by,
    );
  }
}

/// Строка ингредиента из ответа `preview` (брутто/нетто УЖЕ на N порций).
class _PreviewRow {
  _PreviewRow(this.ingredientId, this.name, this.unit, this.brutto, this.netto,
      this.costPerUnit, this.totalCost, this.cookLoss);
  final int? ingredientId;
  final String name;
  final String? unit;
  final double brutto, netto, costPerUnit, totalCost, cookLoss;
}

/// Серверный расчёт из `preview` (рецептура/себестоимость/КБЖУ/аллергены под N).
class _Preview {
  _Preview({
    required this.rows,
    required this.totalCost,
    required this.foodCostPct,
    required this.nutritionPerPortion,
    required this.nutritionTotal,
    required this.allergens,
  });

  final List<_PreviewRow> rows;
  final double totalCost;
  final double foodCostPct;
  final Map<String, double> nutritionPerPortion;
  final Map<String, double> nutritionTotal;
  final List<String> allergens;

  static _Preview? tryParse(dynamic res, {required int portions}) {
    if (res is! Map) return null;
    final m = res.map((k, v) => MapEntry('$k', v));
    double d(dynamic x) =>
        x is num ? x.toDouble() : (double.tryParse('$x') ?? 0);
    Map<String, double> nutr(dynamic x) {
      if (x is! Map) return const {};
      return x.map((k, v) => MapEntry('$k', d(v)));
    }

    final rows = <_PreviewRow>[];
    final ings = m['ingredients'];
    if (ings is List) {
      for (final e in ings) {
        if (e is! Map) continue;
        final r = e.map((k, v) => MapEntry('$k', v));
        rows.add(_PreviewRow(
          (r['ingredient_id'] as num?)?.toInt(),
          '${r['ingredient_name'] ?? r['ingredient_id'] ?? ''}',
          r['unit'] as String?,
          d(r['brutto']),
          d(r['netto']),
          d(r['cost_per_unit']),
          d(r['total_cost']),
          d(r['cooking_loss_coefficient']),
        ));
      }
    }

    final cs = (m['compliance_summary'] as Map?)
            ?.map((k, v) => MapEntry('$k', v)) ??
        const {};
    final allerg =
        (cs['allergens'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    return _Preview(
      rows: rows,
      totalCost: d(m['total_ingredient_cost']),
      foodCostPct: d(m['food_cost']),
      nutritionPerPortion: nutr(cs['nutrition_per_portion']),
      nutritionTotal: nutr(cs['nutrition_total']),
      allergens: allerg,
    );
  }
}

class _Row {
  _Row({
    this.priceKey, // non-null = цену можно править (фронт-расчёт); null = с бэка
    required this.name,
    this.unit,
    required this.bruttoKg,
    required this.nettoKg,
    required this.outKg,
    required this.price,
    required this.sum,
  });
  final String? priceKey;
  final String name;
  final String? unit;
  final double bruttoKg, nettoKg, outKg, price, sum;
}

class _Liquid {
  _Liquid(this.bruttoKg, this.nettoKg, this.outKg);
  final double bruttoKg, nettoKg, outKg;
}

class _Fact {
  _Fact(this.actual, this.actUgarka, this.devPp, this.deltaKg, this.verdict,
      this.label);
  final double actual, actUgarka, devPp, deltaKg;
  final String verdict, label;
}

class _Calc {
  _Calc(
      this.n,
      this.rows,
      this.liquid,
      this.bruttoKg,
      this.nettoKg,
      this.outKg,
      this.cost,
      this.plateG,
      this.cleanLoss,
      this.ugarka,
      this.totalLoss,
      this.yieldPct,
      this.costPerPortion,
      this.costPerKg,
      this.fact);
  final int n;
  final List<_Row> rows;
  final _Liquid? liquid;
  final double bruttoKg,
      nettoKg,
      outKg,
      cost,
      plateG,
      cleanLoss,
      ugarka,
      totalLoss,
      yieldPct,
      costPerPortion,
      costPerKg;
  final _Fact? fact;
}
