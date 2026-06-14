/// Главный финансовый дашборд («Обзор»): полный P&L из
/// `GET /api/v2/dashboard?period=&date=` — объект `financial` ответа.
///
/// Деньги бэкенд может присылать строкой (Decimal) — парсим лояльно.
class FinancialDashboard {
  const FinancialDashboard({
    required this.period,
    required this.date,
    required this.currency,
    required this.sales,
    required this.costs,
    required this.profitability,
    required this.payments,
    required this.production,
    required this.dataQuality,
    required this.daily,
    required this.expenseCategories,
    required this.paymentMethods,
    required this.topItems,
    required this.canViewMoney,
  });

  final String period;
  final String date;
  final String currency;
  final FinSales sales;
  final FinCosts costs;
  final FinProfitability profitability;
  final FinPayments payments;
  final FinProduction production;
  final FinDataQuality dataQuality;
  final List<FinDailyPoint> daily;
  final List<FinCategory> expenseCategories;
  final List<FinPaymentMethod> paymentMethods;
  final List<FinTopItem> topItems;
  final bool canViewMoney;

  factory FinancialDashboard.fromJson(Map<String, dynamic> json) {
    final f = (json['financial'] as Map?)?.cast<String, dynamic>() ?? const {};
    final perms = (json['permissions'] as Map?)?.cast<String, dynamic>();
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    Map<String, dynamic> obj(String key) =>
        (f[key] as Map?)?.cast<String, dynamic>() ?? const {};

    return FinancialDashboard(
      period: json['period']?.toString() ?? 'week',
      date: json['date']?.toString() ?? '',
      currency: f['currency']?.toString() ?? 'KZT',
      sales: FinSales.fromJson(obj('sales')),
      costs: FinCosts.fromJson(obj('costs')),
      profitability: FinProfitability.fromJson(obj('profitability')),
      payments: FinPayments.fromJson(obj('payments')),
      production: FinProduction.fromJson(obj('production')),
      dataQuality: FinDataQuality.fromJson(obj('data_quality')),
      daily: list(f['daily'], FinDailyPoint.fromJson),
      expenseCategories: list(f['expense_categories'], FinCategory.fromJson),
      paymentMethods: list(f['payment_methods'], FinPaymentMethod.fromJson),
      topItems: list(f['top_items'], FinTopItem.fromJson),
      canViewMoney: perms == null ? true : perms['can_view_money'] != false,
    );
  }
}

class FinSales {
  const FinSales({
    this.recognizedRevenue = 0,
    this.grossSales = 0,
    this.netSales = 0,
    this.discountsTotal = 0,
    this.serviceChargeTotal = 0,
    this.ordersTotal = 0,
    this.completedOrders = 0,
    this.openOrders = 0,
    this.cancelledOrders = 0,
    this.averageOrderValue = 0,
    this.discountPct = 0,
  });

  final double recognizedRevenue;
  final double grossSales;
  final double netSales;
  final double discountsTotal;
  final double serviceChargeTotal;
  final int ordersTotal;
  final int completedOrders;
  final int openOrders;
  final int cancelledOrders;
  final double averageOrderValue;
  final double discountPct;

  factory FinSales.fromJson(Map<String, dynamic> j) => FinSales(
    recognizedRevenue: _d(j['recognized_revenue']),
    grossSales: _d(j['gross_sales']),
    netSales: _d(j['net_sales']),
    discountsTotal: _d(j['discounts_total']),
    serviceChargeTotal: _d(j['service_charge_total']),
    ordersTotal: _i(j['orders_total']),
    completedOrders: _i(j['completed_orders']),
    openOrders: _i(j['open_orders']),
    cancelledOrders: _i(j['cancelled_orders']),
    averageOrderValue: _d(j['average_order_value']),
    discountPct: _d(j['discount_pct']),
  );
}

class FinCosts {
  const FinCosts({
    this.cogs = 0,
    this.foodCostPct = 0,
    this.opexTotal = 0,
    this.wasteTotal = 0,
    this.writeOffsTotal = 0,
    this.lossesTotal = 0,
    this.inventoryPurchases = 0,
    this.inventoryConsumption = 0,
  });

  final double cogs;
  final double foodCostPct;
  final double opexTotal;
  final double wasteTotal;
  final double writeOffsTotal;
  final double lossesTotal;
  final double inventoryPurchases;
  final double inventoryConsumption;

  factory FinCosts.fromJson(Map<String, dynamic> j) => FinCosts(
    cogs: _d(j['cogs']),
    foodCostPct: _d(j['food_cost_pct']),
    opexTotal: _d(j['opex_total']),
    wasteTotal: _d(j['waste_total']),
    writeOffsTotal: _d(j['write_offs_total']),
    lossesTotal: _d(j['losses_total']),
    inventoryPurchases: _d(j['inventory_purchases']),
    inventoryConsumption: _d(j['inventory_consumption']),
  );
}

class FinProfitability {
  const FinProfitability({
    this.grossProfit = 0,
    this.grossMarginPct = 0,
    this.operatingProfit = 0,
    this.operatingMarginPct = 0,
  });

  final double grossProfit;
  final double grossMarginPct;
  final double operatingProfit;
  final double operatingMarginPct;

  factory FinProfitability.fromJson(Map<String, dynamic> j) => FinProfitability(
    grossProfit: _d(j['gross_profit']),
    grossMarginPct: _d(j['gross_margin_pct']),
    operatingProfit: _d(j['operating_profit']),
    operatingMarginPct: _d(j['operating_margin_pct']),
  );
}

class FinPayments {
  const FinPayments({
    this.netPayments = 0,
    this.pendingPayments = 0,
    this.refundsTotal = 0,
    this.collectionRatePct = 0,
    this.cashPayments = 0,
    this.cashlessPayments = 0,
  });

  final double netPayments;
  final double pendingPayments;
  final double refundsTotal;
  final double collectionRatePct;
  final double cashPayments;
  final double cashlessPayments;

  factory FinPayments.fromJson(Map<String, dynamic> j) => FinPayments(
    netPayments: _d(j['net_payments']),
    pendingPayments: _d(j['pending_payments']),
    refundsTotal: _d(j['refunds_total']),
    collectionRatePct: _d(j['collection_rate_pct']),
    cashPayments: _d(j['cash_payments']),
    cashlessPayments: _d(j['cashless_payments']),
  );
}

class FinProduction {
  const FinProduction({
    this.theoreticalFoodCost = 0,
    this.actualFoodCost = 0,
    this.varianceCost = 0,
    this.variancePct = 0,
    this.costPerMeal = 0,
    this.mealsServed = 0,
  });

  final double theoreticalFoodCost;
  final double actualFoodCost;
  final double varianceCost;
  final double variancePct;
  final double costPerMeal;
  final int mealsServed;

  factory FinProduction.fromJson(Map<String, dynamic> j) => FinProduction(
    theoreticalFoodCost: _d(j['theoretical_food_cost']),
    actualFoodCost: _d(j['actual_food_cost']),
    varianceCost: _d(j['variance_cost']),
    variancePct: _d(j['variance_pct']),
    costPerMeal: _d(j['cost_per_meal']),
    mealsServed: _i(j['meals_served']),
  );
}

class FinDataQuality {
  const FinDataQuality({
    this.overallCompletenessPct = 100,
    this.completedOrderItems = 0,
    this.orderItemsWithoutCost = 0,
    this.activeMenuItems = 0,
    this.menuItemsWithoutRecipe = 0,
    this.acceptedReceiptItems = 0,
    this.receiptItemsWithoutCost = 0,
    this.costCoveragePct = 100,
    this.recipeCoveragePct = 100,
    this.receiptCostCoveragePct = 100,
    this.warnings = const [],
  });

  final double overallCompletenessPct;
  final int completedOrderItems;
  final int orderItemsWithoutCost;
  final int activeMenuItems;
  final int menuItemsWithoutRecipe;
  final int acceptedReceiptItems;
  final int receiptItemsWithoutCost;
  final double costCoveragePct;
  final double recipeCoveragePct;
  final double receiptCostCoveragePct;
  final List<String> warnings;

  factory FinDataQuality.fromJson(Map<String, dynamic> j) => FinDataQuality(
    overallCompletenessPct: _d(j['overall_completeness_pct']),
    completedOrderItems: _i(j['completed_order_items']),
    orderItemsWithoutCost: _i(j['order_items_without_cost']),
    activeMenuItems: _i(j['active_menu_items']),
    menuItemsWithoutRecipe: _i(j['menu_items_without_recipe']),
    acceptedReceiptItems: _i(j['accepted_receipt_items']),
    receiptItemsWithoutCost: _i(j['receipt_items_without_cost']),
    costCoveragePct: _d(j['cost_coverage_pct']),
    recipeCoveragePct: _d(j['recipe_coverage_pct']),
    receiptCostCoveragePct: _d(j['receipt_cost_coverage_pct']),
    warnings:
        (j['warnings'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

class FinDailyPoint {
  const FinDailyPoint({
    this.date = '',
    this.recognizedRevenue = 0,
    this.cogs = 0,
    this.opex = 0,
    this.operatingProfit = 0,
  });

  final String date;
  final double recognizedRevenue;
  final double cogs;
  final double opex;
  final double operatingProfit;

  factory FinDailyPoint.fromJson(Map<String, dynamic> j) => FinDailyPoint(
    date: j['date']?.toString() ?? '',
    recognizedRevenue: _d(j['recognized_revenue']),
    cogs: _d(j['cogs']),
    opex: _d(j['opex']),
    operatingProfit: _d(j['operating_profit']),
  );
}

class FinCategory {
  const FinCategory({this.category = '', this.amount = 0, this.sharePct = 0});

  final String category;
  final double amount;
  final double sharePct;

  factory FinCategory.fromJson(Map<String, dynamic> j) => FinCategory(
    category: j['category']?.toString() ?? '',
    amount: _d(j['amount']),
    sharePct: _d(j['share_pct']),
  );
}

class FinPaymentMethod {
  const FinPaymentMethod({
    this.paymentType = '',
    this.netAmount = 0,
    this.count = 0,
  });

  final String paymentType;
  final double netAmount;
  final int count;

  factory FinPaymentMethod.fromJson(Map<String, dynamic> j) => FinPaymentMethod(
    paymentType: j['payment_type']?.toString() ?? '',
    netAmount: _d(j['net_amount']),
    count: _i(j['count']),
  );
}

class FinTopItem {
  const FinTopItem({
    this.name = '',
    this.quantity = 0,
    this.revenue = 0,
    this.grossProfit = 0,
    this.grossMarginPct = 0,
  });

  final String name;
  final int quantity;
  final double revenue;
  final double grossProfit;
  final double grossMarginPct;

  factory FinTopItem.fromJson(Map<String, dynamic> j) => FinTopItem(
    name: j['name']?.toString() ?? '',
    quantity: _i(j['quantity']),
    revenue: _d(j['revenue']),
    grossProfit: _d(j['gross_profit']),
    grossMarginPct: _d(j['gross_margin_pct']),
  );
}

double _d(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _i(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
